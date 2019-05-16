module Typecheck where

import AbsGrammar
import LexGrammar
import ParGrammar
import Control.Monad.Reader
import Control.Monad.State
import Prelude hiding (lookup)
import Data.Map.Lazy hiding (foldr)
import ErrM

data Ty
    = TVar Ident | TList Ty | TApp Ty Ty | TBool | TInt | Ty :-> Ty | TNone
  deriving (Ord, Show)

instance Eq Ty where
    TNone == _ = True
    _ == TNone = True
    TList t1 == TList t2 = t1 == t2
    TBool == TBool = True
    TInt == TInt = True
    t1 :-> t2 == q1 :-> q2 = t1 == q1 && t2 == q2
    TApp t1 t2 == TApp q1 q2 = t1 == q1 && t2 == q2
    TVar i1 == TVar i2 = error "Not implemented"
    _ == _ = False

data LazyType = LazyT Expr TypeEnv | AlreadyT Ty
type TypeEnv = Map Ident LazyType

instance Show LazyType where
  show (LazyT expr _) = show expr
  show (AlreadyT ty) = show ty

-- data Pattern = PatValue Value | PatDefault | PatIdent Ident | PatListHeadIdent Ident Pattern | PatListHeadLit Value Pattern
-- data TopPattern = TopAtPat Ident Pattern | TopPat Pattern
-- data Alternative = Alt TopPattern Expr

failure :: Show d => d -> ReaderT TypeEnv Err a
failure x = fail $ "Not implemented yet: " ++ show x

failureState :: Decl -> StateT TypeEnv Err ()
failureState x = fail $ "Not implemented yet: " ++ show x

errMsg :: Ty -> Ty -> String
errMsg expected got = 
    "Typing error in expression: expected " ++ (show expected) ++ ", got " ++ (show got)

errMsgIn :: Ty -> Ty -> String -> String
errMsgIn expected got place = 
    "Typing error in " ++ place ++ ": expected " ++ (show expected) ++ ", got " ++ (show got)

transETy :: ETy -> Ty
transETy x = case x of
  -- ETVar ident -> failure x
  ETList ety -> TList $ transETy ety
  ETApp ety1 ety2 -> TApp (transETy ety1) (transETy ety2)
  ETBool -> TBool
  ETInt -> TInt
  ETArrow ety1 ety2 ->  (transETy ety1) :-> (transETy ety2)

inferLit :: Lit -> ReaderT TypeEnv Err Ty
inferLit x = case x of
  LitInt _ -> return $ TInt
  LitTrue -> return $ TBool
  LitFalse -> return $ TBool
  LitList [] -> return $ TList TNone
  LitList exprs -> do
    types <- mapM (\e -> inferExpr e) exprs 
    listType <- foldM (\lastTy -> \ty -> 
        if ty == lastTy then 
            return ty 
        else 
            fail $ "Typing error in list expression: expected " ++ (show lastTy) ++ ", got " ++ (show ty)) (head types) types
    return $ TList listType

inferEAlt :: EAlt -> Ty -> ReaderT TypeEnv Err (Ty, Ty)
inferEAlt x caseExprTy = case x of
  EAltCase etoppattern expr -> do 
    (patTy, altEnv) <- inferETopPattern etoppattern caseExprTy
    exprTy <- local (\_ -> altEnv) (inferExpr expr)
    return (patTy, exprTy)

inferETopPattern :: ETopPattern -> Ty -> ReaderT TypeEnv Err (Ty, TypeEnv)
inferETopPattern x caseExprTy = case x of
  ETopPatternAt ident epattern -> do
    (t, e) <- inferEPattern epattern caseExprTy
    return (t, insert ident (AlreadyT t) e)
  ETopPatternNo epattern -> inferEPattern epattern caseExprTy

inferEPattern :: EPattern -> Ty -> ReaderT TypeEnv Err (Ty, TypeEnv)
inferEPattern x caseExprTy = case x of
  -- EPatData ident epatconstrargs -> failure x
  EPatLit lit -> do
    env <- ask
    litTy <- inferLit lit
    return (litTy, env)
  EPatIdent ident -> do
    env <- ask
    return (TNone, insert ident (AlreadyT caseExprTy) env)
  EPatDefault -> do 
    env <- ask
    return (TNone, env)
  EPatHeadIdent ident epattern -> do
    elemTy <- case caseExprTy of 
        TList t -> return t
        _ -> fail $ errMsg (TList TNone) caseExprTy 
    (patTy, patEnv) <- inferEPattern epattern caseExprTy
    return (patTy, insert ident (AlreadyT elemTy) patEnv)
  EPatHeadLit lit epattern -> do
    litTy <- inferLit lit
    (listPatTy, patEnv) <- inferEPattern epattern caseExprTy
    ty <- case listPatTy of 
        TList patTy -> 
            if litTy == patTy then
                return (TList litTy)
            else 
                fail $ errMsgIn litTy patTy "list matching pattern"
        TNone -> return (TList litTy)
        _ -> fail $ errMsg (TList litTy) listPatTy
    return (ty, patEnv)

checkBiOp :: Ty -> Expr -> Expr -> ReaderT TypeEnv Err Ty
checkBiOp expected expr1 expr2 = do 
    ty1 <- inferExpr expr1
    ty2 <- inferExpr expr2
    if ty1 /= expected then
        fail $ errMsg expected ty1
    else if ty2 /= expected then
        fail $ errMsg expected ty2
    else
        return expected

inferExpr :: Expr -> ReaderT TypeEnv Err Ty
inferExpr x = case x of
  EVar ident@(Ident idString) -> do
    env <- ask
    case lookup ident env of
        Just (AlreadyT val) -> return val
        Just (LazyT expr lazyEnv) -> 
            local (\_ -> lazyEnv) (inferExpr expr) 
        Nothing -> fail $ "Variable undeclared: " ++ idString
  ELit lit -> inferLit lit
  Neg expr -> do
    ty <- inferExpr expr
    if ty == TInt then return TInt else fail $ errMsg TInt ty
  Not expr -> do
    ty <- inferExpr expr
    if ty == TBool then return TBool else fail $ errMsg TBool ty
  EMul expr1 _ expr2 -> checkBiOp TInt expr1 expr2
  EAdd expr1 _ expr2 -> checkBiOp TInt expr1 expr2
  ERel expr1 _ expr2 -> do
    checkBiOp TInt expr1 expr2
    return TBool
  EAnd expr1 expr2 -> checkBiOp TBool expr1 expr2
  EOr expr1 expr2 -> checkBiOp TBool expr1 expr2
  
  ECons expr1 expr2 -> do
    tyHead <- inferExpr expr1
    tyTail <- inferExpr expr2
    case tyTail of
        TList ty -> if tyHead == ty then return $ TList ty else fail $ errMsg tyHead ty  
        _ -> fail $ errMsg (TList tyHead) tyTail 
  EApp expr1 expr2 -> do 
    fTy <- inferExpr expr1
    argTy <- inferExpr expr2
    case fTy of 
        t :-> q -> 
            if t == argTy then
                return q 
            else 
                fail $ errMsgIn t argTy "function argument" 
        _ -> fail $ "Expected a function type, got " ++ (show fTy)
  Lambda (BindMulti ((BindElemT ident ety):otherBinds)) expr -> do
    env <- ask
    let bindTy = transETy ety
    restTy <- case otherBinds of 
                [] -> local (insert ident (AlreadyT bindTy)) (inferExpr expr)
                _ -> local (insert ident (AlreadyT bindTy)) (inferExpr $ Lambda (BindMulti otherBinds) expr)
    return $ bindTy :-> restTy

  Let decls expr -> do
    letEnv <- ask
    envWithDecls <- return $ foldM (\env -> \decl -> execStateT (typeDecl decl) env) letEnv decls
    case envWithDecls of 
      Ok env -> local (\_ -> env) (inferExpr expr)
      Bad err -> fail err

  Case expr ealts -> do
    exprTy <- inferExpr expr
    altTyPairs <- mapM (\alt -> inferEAlt alt exprTy) ealts
    caseTy <- foldM (\lastExprTy -> \(altPatTy, altExprTy) -> 
        if altExprTy == lastExprTy && altPatTy == exprTy then 
            return altExprTy 
        else if altExprTy /= lastExprTy then
            fail $ errMsgIn lastExprTy altExprTy "case expression"
        else -- altPatTy /= exprTy -- Type of the pattern does not match the case expr type.
            fail $ errMsgIn exprTy altPatTy "case alternative"
        ) (snd $ head altTyPairs) altTyPairs
    return caseTy
  
  If expr1 expr2 expr3 -> do
    condTy <- inferExpr expr1
    trueTy <- inferExpr expr2
    falseTy <- inferExpr expr3
    if condTy /= TBool then
        fail $ errMsg TBool condTy
    else if trueTy /= falseTy then
        fail $ errMsgIn trueTy falseTy "if branches"
    else 
        return trueTy

typeDecl :: Decl -> StateT TypeEnv Err ()
typeDecl x = case x of
  VDecl ident@(Ident i) ety expr -> do 
      let ty = transETy ety
      env <- get
      let newEnv = insert ident (LazyT expr newEnv) env
      put newEnv
      t <- case (runReaderT (inferExpr expr) newEnv) of 
            Ok t -> return t
            Bad err -> fail err  
      if ty == t then
          put $ insert ident (AlreadyT ty) env 
      else 
          fail $ "Typing error for variable " ++ i ++ ": expected " ++ (show ty) ++ ", got " ++ (show t)
  FDecl ident idents ty expr -> failureState x
  DDecl ident constrargs constrdefs -> failureState x

typeProg :: Prog -> Err TypeEnv
typeProg (Program decls) =
    foldM (\env -> \decl -> execStateT (typeDecl decl) env) empty decls  

asPrintableTypeEnv :: TypeEnv -> Err [String]
asPrintableTypeEnv env = 
  let 
    listEnv = toList env 
    evalLazyExpr (Ident ident, envTy) =
      case envTy of 
        LazyT expr lazyEnv -> runReaderT (inferExpr expr) lazyEnv >>= \ty -> return (ident, ty)
        AlreadyT ty -> return (ident, ty)
  in
  mapM evalLazyExpr listEnv  
    >>= \lst -> return (Prelude.map (\(ident, ty) -> ident ++ " = " ++ (show ty)) lst)

typecheck :: String -> IO ()
typecheck s = case ((pProg $ myLexer s) >>= typeProg >>= asPrintableTypeEnv) of 
  Ok results -> mapM_ putStrLn results
  Bad errString -> putStrLn $ "ERROR DURING TYPE CHECKING: " ++ errString