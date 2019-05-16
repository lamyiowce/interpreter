module Interpreter where
import Prelude hiding (lookup)

import AbsGrammar
import LexGrammar
import ParGrammar
import Control.Monad.Reader
import Control.Monad.State
import Data.Map.Lazy hiding (foldl)
import ErrM
data Value = ValInt Integer | ValBool Bool | ValList [Value] | ValLambda [Ident] LazyValue deriving (Show, Eq)
data LazyValue = LazyVal Expr Env | AlreadyVal Value deriving (Eq)

instance Show LazyValue where
  show (LazyVal expr env) = show expr
  show (AlreadyVal val) = show val

type Loc = Integer
type Env = Map Ident LazyValue

data Pattern = PatValue Value | PatDefault | PatIdent Ident | PatListHeadIdent Ident Pattern | PatListHeadLit Value Pattern
data TopPattern = TopAtPat Ident Pattern | TopPat Pattern
data Alternative = Alt TopPattern Expr

failure :: Expr -> ReaderT Env Err Value
failure x = fail $ "Not implemented yet: " ++ show x

failureState :: Decl -> StateT Env Err ()
failureState x = fail $ "Not implemented yet: " ++ show x

transLit :: Lit -> ReaderT Env Err Value
transLit x = case x of
  LitInt integer -> return $ ValInt integer
  LitTrue -> return $ ValBool True
  LitFalse -> return $ ValBool False
  LitList exprs -> do
    litList <- mapM (\e -> transExpr e) exprs >>= (\valList -> return $ ValList valList)
    return litList

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

transEAlt :: EAlt -> ReaderT Env Err Alternative
transEAlt x = case x of
  EAltCase etoppattern expr -> do
    p <- transETopPattern etoppattern
    return $ Alt p expr

transETopPattern :: ETopPattern -> ReaderT Env Err TopPattern
transETopPattern x = case x of
  ETopPatternAt ident epattern -> do
    p <- transEPattern epattern 
    return $ TopAtPat ident p
  ETopPatternNo epattern -> do 
    p <- transEPattern epattern
    return $ TopPat p

transEPattern :: EPattern -> ReaderT Env Err Pattern
transEPattern x = case x of
  EPatDefault -> return PatDefault
  EPatLit lit -> do
    val <- transLit lit
    return $ PatValue val 
  EPatIdent ident -> return $ PatIdent ident
  EPatHeadIdent ident epattern -> do
    insidePattern <- transEPattern epattern
    return $ PatListHeadIdent ident insidePattern
  EPatHeadLit lit epattern -> do
    litVal <- transLit lit 
    insidePattern <- transEPattern epattern
    return $ PatListHeadLit litVal insidePattern
  -- EPatData ident epatconstrargs -> failure x

-- transEPatConstrArg :: EPatConstrArg -> Result
-- transEPatConstrArg x = case x of
--   EPatConstrArgDef ident -> failure x

-- Check if the pattern matches the value.
isMatchTop :: Env -> TopPattern -> Value -> Bool 
isMatchTop env pat val = 
  let 
    p = case pat of
          TopAtPat _ p -> p
          TopPat p -> p
  in
  isMatch env p val

isMatch :: Env -> Pattern -> Value -> Bool
isMatch env p val = 
  case (p, val) of 
    (PatDefault, _) -> True
    (PatValue patVal, val) -> patVal == val
    (PatIdent _, _) -> True
    (PatListHeadIdent _ pat, ValList (_:valTail)) -> isMatch env pat (ValList valTail)
    (PatListHeadLit val pat, ValList (hd:valTail)) -> val == hd && isMatch env pat (ValList valTail)
    (_, _) -> False

-- Add declarations from the pattern matching to the environment.
addTopPatternToEnv :: TopPattern -> Value -> Env -> Env
addTopPatternToEnv pat val env = case pat of
  TopPat p -> addPatternToEnv p val env
  TopAtPat ident p -> insert ident (AlreadyVal val) (addPatternToEnv p val env)

-- Already checked that the patterm matches the value/expr.
addPatternToEnv :: Pattern -> Value -> Env -> Env
addPatternToEnv pat val env = case pat of 
  PatDefault -> env
  PatValue _ -> env
  PatIdent ident -> insert ident (AlreadyVal val) env
  PatListHeadIdent ident pat -> case val of 
      ValList (h:valTail) -> insert ident (AlreadyVal h) (addPatternToEnv pat val env)
  PatListHeadLit _ pat -> case val of 
      ValList (_:valTail) -> addPatternToEnv pat (ValList valTail) env


transExpr :: Expr -> ReaderT Env Err Value
transExpr x = case x of
  EVar ident@(Ident idString) -> do
    env <- ask
    value <- case lookup ident env of
            Just (AlreadyVal val) -> return val
            Just (LazyVal expr lazyEnv) -> local (\_ -> lazyEnv) (transExpr expr)
            Nothing -> fail $ "Variable undeclared: " ++ idString
    return value
  ELit lit -> transLit lit

  EApp expr1 argExpr -> do
    fun <- transExpr expr1 
    env <- ask
    case fun of 
      ValLambda binds (LazyVal lazyExpr bodyEnv) -> 
          case binds of
              ident:[] -> local (\e -> insert ident (LazyVal argExpr e) bodyEnv) (transExpr lazyExpr)
              ident:otherBinds -> return $ ValLambda otherBinds (LazyVal lazyExpr (insert ident (LazyVal argExpr env) bodyEnv))
    
  ECons expr1 expr2 -> do
    v1 <- transExpr expr1
    ValList v2 <- transExpr expr2
    return $ ValList (v1:v2)

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

  If expr1 expr2 expr3 -> do
    ValBool cond <- transExpr expr1
    case cond of
      True -> transExpr expr2
      False -> transExpr expr3
  Case expr alts -> do
    val <- transExpr expr 
    env <- ask
    altPats <- mapM (\alt -> transEAlt alt) alts 
    let 
      foldAux maybeMatched nextAlt@(Alt topPat altExpr) = 
        case maybeMatched of
          Just matchedAlt -> Just matchedAlt
          Nothing -> if isMatchTop env topPat val then Just nextAlt else Nothing
    case foldl foldAux Nothing altPats of
      Nothing -> fail "Non-exhaustive pattern matching"
      Just (Alt pat patExpr) -> local (addTopPatternToEnv pat val) (transExpr patExpr) 

  Lambda (BindMulti binds) expr -> do
    env <- ask
    return $ ValLambda (Prelude.map (\(BindElemT ident _) -> ident) binds) (LazyVal expr env)

  Let decls expr -> do
    letEnv <- ask
    envWithDecls <- return $ foldM (\env -> \decl -> execStateT (transDecl decl) env) letEnv decls
    case envWithDecls of 
      Ok env -> local (\_ -> env) (transExpr expr)
      Bad err -> fail err

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
  DDecl ident constrargs constrdefs -> failureState x

transProg :: Prog -> Err Env
transProg (Program decls) = 
  foldM (\env -> \decl -> execStateT (transDecl decl) env) empty decls 

evalExpr :: Env -> Expr -> Err Value
evalExpr s exp = runReaderT (transExpr exp) s

asPrintableEnv :: Env -> Err [String]
asPrintableEnv env = 
  let 
    listEnv = toList env 
    evalLazyExpr (Ident ident, envVal) =
      case envVal of 
        LazyVal expr lazyEnv -> evalExpr lazyEnv expr >>= \val -> return (ident, val)
        AlreadyVal val -> return (ident, val)
  in
  mapM evalLazyExpr listEnv
    >>= \lst -> return (Prelude.map (\(ident, val) -> ident ++ " = " ++ (show val)) lst)

parseExpr :: String -> Err Value
parseExpr s = pExpr (myLexer s) >>= evalExpr empty

interpret :: String -> IO ()
interpret s = case ((pProg $ myLexer s) >>= transProg >>= asPrintableEnv) of 
  Ok results -> mapM_ putStrLn results
  Bad errString -> putStrLn $ "ERROR: " ++ errString