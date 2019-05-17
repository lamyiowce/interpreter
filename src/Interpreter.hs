module Interpreter where
import Prelude hiding (lookup)

import AbsGrammar
import LexGrammar
import ParGrammar
import PrintGrammar
import Control.Monad.Reader
import Control.Monad.State
import Data.Map.Lazy hiding (foldl, map)
import ErrM

-- Types representing values and lazy values. ---
data Value = ValInt Integer | ValBool Bool | ValList [Value] | ValLambda [Ident] LazyValue deriving Eq
data LazyValue = LazyVal Expr Env | AlreadyVal Value deriving (Eq)

instance Show Value where
  show (ValInt i) = show i
  show (ValBool b) = show b
  show (ValList l) = show l
  show (ValLambda idents lazyVal) = show (map (\(Ident i) -> i) idents) ++ " -> " ++ (show lazyVal)

instance Show LazyValue where
  show (LazyVal expr env) = printTree expr
  show (AlreadyVal val) = show val

-- Environment: maps var/fun ids to lazy values - 
type Env = Map Ident LazyValue

-- Monadically convert parsed literal to a value.
transLit :: Lit -> ReaderT Env Err Value
transLit x = case x of
  LitInt integer -> return $ ValInt integer
  LitTrue -> return $ ValBool True
  LitFalse -> return $ ValBool False
  LitList exprs -> do
    litList <- mapM (\e -> transExpr e) exprs >>= (\valList -> return $ ValList valList)
    return litList

-- Helper functions for interpreting binary operations.
transAddOp :: Num a => AddOp -> a -> a -> a
transAddOp x = case x of
  Plus -> (+)
  Minus -> (-)

transMulOp :: Integral a => MulOp -> a -> a -> a
transMulOp x = case x of
  Times -> (*)
  Div -> div

transRelOp :: Ord a => RelOp -> a -> a -> Bool
transRelOp x = case x of
  LTH -> (<)
  LE -> (<=)
  GTH -> (>)
  GE -> (>=)
  EQU -> (==)
  NE -> (/=)

-- Pattern matching. ----------------------------

-- Check if the pattern matches the value.
isMatchTop :: Env -> ETopPattern -> Value -> ReaderT Env Err Bool 
isMatchTop env pat val = 
  let 
    p = case pat of
          ETopPatternAt _ p -> p
          ETopPatternNo p -> p
  in
  isMatch env p val

isMatch :: Env -> EPattern -> Value -> ReaderT Env Err Bool
isMatch env p val = 
  case (p, val) of 
    (EPatDefault, _) -> return True
    (EPatLit patLit, val) -> do 
      l <- transLit patLit
      return $ l == val
    (EPatIdent _, _) -> return True
    (EPatHeadIdent _ pat, ValList (_:valTail)) -> isMatch env pat (ValList valTail)
    (EPatHeadLit lit pat, ValList (hd:valTail)) -> do
      l <- transLit lit
      rest <- isMatch env pat (ValList valTail)
      return $ hd == l && rest
    (_, _) -> return False

-- Add declarations from the pattern matching to the environment.
addTopPatternToEnv :: ETopPattern -> Value -> Env -> Env
addTopPatternToEnv pat val env = case pat of
  ETopPatternNo p -> addPatternToEnv p val env
  ETopPatternAt ident p -> insert ident (AlreadyVal val) (addPatternToEnv p val env)

-- Already checked that the patterm matches the value/expr,
-- so no need to handle errors.
addPatternToEnv :: EPattern -> Value -> Env -> Env
addPatternToEnv pat val env = case pat of 
  EPatDefault -> env
  EPatLit _ -> env
  EPatIdent ident -> insert ident (AlreadyVal val) env
  EPatHeadIdent ident pat -> case val of 
      ValList (h:valTail) -> insert ident (AlreadyVal h) (addPatternToEnv pat (ValList valTail) env)
  EPatHeadLit _ pat -> case val of 
      ValList (_:valTail) -> addPatternToEnv pat (ValList valTail) env

-- Evaluate expression to Value.
transExpr :: Expr -> ReaderT Env Err Value
transExpr x = case x of

-- Integer operations --------------------
  Neg expr -> do
    ValInt v <- transExpr expr
    return $ ValInt $ -v
  EMul expr1 op expr2 -> do
    ValInt v1 <- transExpr expr1
    ValInt v2 <- transExpr expr2
    case (op, v2) of
      (Div, 0) -> fail "Division by zero. This incident will be reported."
      _ -> return $ ValInt $ (transMulOp op) v1 v2
  EAdd expr1 op expr2 -> do
    ValInt v1 <- transExpr expr1
    ValInt v2 <- transExpr expr2
    return $ ValInt $ (transAddOp op) v1 v2

-- Boolean values operations --------------
  Not expr -> do
    ValBool b <- transExpr expr
    return $ ValBool $ not b
  ERel expr1 op expr2 -> do
    ValInt v1 <- transExpr expr1
    ValInt v2 <- transExpr expr2
    return $ ValBool $ (transRelOp op) v1 v2
  EAnd expr1 expr2 -> do
    ValBool b1 <- transExpr expr1
    ValBool b2 <- transExpr expr2
    return $ ValBool $ b1 && b2
  EOr expr1 expr2 -> do
    ValBool b1 <- transExpr expr1
    ValBool b2 <- transExpr expr2
    return $ ValBool $ b1 || b2

  -- Variable or function from env.
  EVar ident@(Ident idString) -> do
    env <- ask
    value <- case lookup ident env of
            Just (AlreadyVal val) -> return val
            Just (LazyVal expr lazyEnv) -> local (\_ -> lazyEnv) (transExpr expr)
            Nothing -> fail $ "Variable undeclared: " ++ idString
    return value

  -- Literals.
  ELit lit -> transLit lit

  -- Function application.
  EApp expr1 argExpr -> do
    fun <- transExpr expr1 
    env <- ask
    case fun of 
      ValLambda binds (LazyVal lazyExpr bodyEnv) -> 
          case binds of
              ident:[] -> local (\e -> insert ident (LazyVal argExpr e) bodyEnv) (transExpr lazyExpr)
              ident:otherBinds -> return $ ValLambda otherBinds (LazyVal lazyExpr (insert ident (LazyVal argExpr env) bodyEnv))
    
  -- List construction using ":".
  ECons expr1 expr2 -> do
    v1 <- transExpr expr1
    ValList v2 <- transExpr expr2
    return $ ValList (v1:v2)

  If expr1 expr2 expr3 -> do
    ValBool cond <- transExpr expr1
    case cond of
      True -> transExpr expr2
      False -> transExpr expr3
  Case expr alts -> do
    val <- transExpr expr 
    env <- ask
    let 
      foldAux maybeMatched nextAlt@(EAltCase topPat altExpr) = 
        case maybeMatched of
          Just matchedAlt -> return $ Just matchedAlt
          Nothing -> do 
            b <- isMatchTop env topPat val 
            if b then return $ Just nextAlt else return Nothing
    alt <- foldM foldAux Nothing alts 
    case alt of
      Nothing -> fail $ "Non-exhaustive pattern matching in case: no match for value " ++ show (val)
      Just (EAltCase pat patExpr) -> local (addTopPatternToEnv pat val) (transExpr patExpr) 

  Lambda (BindMulti binds) expr -> do
    env <- ask
    return $ ValLambda (Prelude.map (\(BindElemT ident _) -> ident) binds) (LazyVal expr env)

  Let decls expr -> do
    letEnv <- ask
    envWithDecls <- return $ foldM (\env -> \decl -> execStateT (transDecl decl) env) letEnv decls
    case envWithDecls of 
      Ok env -> local (\_ -> env) (transExpr expr)
      Bad err -> fail err

-- Add declarations to environment, recursive declarations
-- work because of Haskell's lazy evaluation.
transDecl :: Decl -> StateT Env Err ()
transDecl x = case x of
  VDecl ident ty expr -> do
    env <- get
    let newEnv = insert ident (LazyVal expr newEnv) env 
    put newEnv
  FDecl ident args _ expr -> do
    env <- get
    let newEnv = insert ident (AlreadyVal $ ValLambda args (LazyVal expr newEnv)) env 
    put newEnv 

transProgWithEnv :: Env -> Prog -> Err Env
transProgWithEnv e (Program decls) = 
  foldM (\env -> \decl -> execStateT (transDecl decl) env) e decls 

transProg :: Prog -> Err Env
transProg = transProgWithEnv empty 

evalExpr :: Env -> Expr -> Err Value
evalExpr s exp = runReaderT (transExpr exp) s
