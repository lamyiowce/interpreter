module Interpreter where
import Prelude hiding (lookup)

import AbsGrammar
import LexGrammar
import ParGrammar
import Control.Monad.Reader
import Data.Map.Lazy
import ErrM
data Value = ValInt Integer | ValBool Bool | ValList [Value] | ValFun [Ident] LazyValue deriving (Show, Eq)
data LazyValue = LazyVal Expr Env Store deriving (Show, Eq)
type Loc = Integer
type Env = Map Ident Loc
type Store = Map Loc LazyValue

failure :: Expr -> ReaderT (Env, Store) Err Value
failure x = fail $ "Not implemented yet: " ++ show x

transLit :: Lit -> ReaderT (Env, Store) Err Value
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

transExpr :: Expr -> ReaderT (Env, Store) Err Value
transExpr x = case x of
  EVar ident@(Ident idString) -> do
    (env, store) <- ask
    value <- case lookup ident env >>= (\loc -> lookup loc store) of
            Just (LazyVal expr lazyEnv lazyStore) -> local (\_ -> (lazyEnv, lazyStore)) (transExpr expr)
            Nothing -> fail $ "Variable undeclared: " ++ idString
    return value
  ELit lit -> transLit lit
  EApp expr1 expr2 -> failure x
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
    return $ ValInt $ (transMulOp op) v1 v2
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
  Case expr alts -> failure x

  Lambda (BindMulti binds) expr -> do
    (e, s) <- ask
    return $ ValFun (Prelude.map (\(BindElemT ident _) -> ident) binds) (LazyVal expr e s)
  Let decls expr -> failure x

evalExpr :: (Env, Store) -> Expr -> Err Value
evalExpr s exp = runReaderT (transExpr exp) s

parse :: String -> Err Value
parse s = pExpr (myLexer s) >>= evalExpr (empty, empty)
--interpretDecl :: Decl -> (Env, Store)

--interpret :: Prog -> (Env, Store)
--interpret (Program decls) = Prelude.foldl evalDecl (empty, empty) decls