-- This Happy file was machine-generated by the BNF converter
{
{-# OPTIONS_GHC -fno-warn-incomplete-patterns -fno-warn-overlapping-patterns #-}
module ParGrammar where
import AbsGrammar
import LexGrammar
import ErrM

}

%name pProg Prog
%name pLit Lit
%name pExpr8 Expr8
%name pExpr7 Expr7
%name pExpr3 Expr3
%name pExpr6 Expr6
%name pExpr5 Expr5
%name pExpr4 Expr4
%name pExpr2 Expr2
%name pExpr1 Expr1
%name pExpr Expr
%name pListExpr ListExpr
%name pAddOp AddOp
%name pMulOp MulOp
%name pRelOp RelOp
%name pDecl Decl
%name pListIdent ListIdent
%name pConstrDef ConstrDef
%name pConstrArg ConstrArg
%name pListConstrArg ListConstrArg
%name pListConstrDef ListConstrDef
%name pListDecl ListDecl
%name pETy2 ETy2
%name pETy1 ETy1
%name pETy ETy
%name pBind Bind
%name pBindElem BindElem
%name pListBindElem ListBindElem
%name pEAlt EAlt
%name pETopPattern ETopPattern
%name pEPattern EPattern
%name pEPatConstrArg EPatConstrArg
%name pListEPatConstrArg ListEPatConstrArg
%name pListEAlt ListEAlt
-- no lexer declaration
%monad { Err } { thenM } { returnM }
%tokentype {Token}
%token
  '!' { PT _ (TS _ 1) }
  '!=' { PT _ (TS _ 2) }
  '&&' { PT _ (TS _ 3) }
  '(' { PT _ (TS _ 4) }
  ')' { PT _ (TS _ 5) }
  '*' { PT _ (TS _ 6) }
  '+' { PT _ (TS _ 7) }
  ',' { PT _ (TS _ 8) }
  '-' { PT _ (TS _ 9) }
  '->' { PT _ (TS _ 10) }
  '/' { PT _ (TS _ 11) }
  ':' { PT _ (TS _ 12) }
  '::' { PT _ (TS _ 13) }
  ';' { PT _ (TS _ 14) }
  '<' { PT _ (TS _ 15) }
  '<=' { PT _ (TS _ 16) }
  '=' { PT _ (TS _ 17) }
  '==' { PT _ (TS _ 18) }
  '>' { PT _ (TS _ 19) }
  '>=' { PT _ (TS _ 20) }
  '@' { PT _ (TS _ 21) }
  'Bool' { PT _ (TS _ 22) }
  'Int' { PT _ (TS _ 23) }
  'List' { PT _ (TS _ 24) }
  '[' { PT _ (TS _ 25) }
  '\\' { PT _ (TS _ 26) }
  ']' { PT _ (TS _ 27) }
  '_' { PT _ (TS _ 28) }
  'case' { PT _ (TS _ 29) }
  'data' { PT _ (TS _ 30) }
  'else' { PT _ (TS _ 31) }
  'false' { PT _ (TS _ 32) }
  'if' { PT _ (TS _ 33) }
  'in' { PT _ (TS _ 34) }
  'let' { PT _ (TS _ 35) }
  'of' { PT _ (TS _ 36) }
  'then' { PT _ (TS _ 37) }
  'true' { PT _ (TS _ 38) }
  '{' { PT _ (TS _ 39) }
  '|' { PT _ (TS _ 40) }
  '||' { PT _ (TS _ 41) }
  '}' { PT _ (TS _ 42) }

L_integ  { PT _ (TI $$) }
L_ident  { PT _ (TV $$) }


%%

Integer :: { Integer } : L_integ  { (read ( $1)) :: Integer }
Ident   :: { Ident }   : L_ident  { Ident $1 }

Prog :: { Prog }
Prog : ListDecl { AbsGrammar.Program $1 }
Lit :: { Lit }
Lit : Integer { AbsGrammar.LitInt $1 }
    | 'true' { AbsGrammar.LitTrue }
    | 'false' { AbsGrammar.LitFalse }
    | '[' ListExpr ']' { AbsGrammar.LitList $2 }
Expr8 :: { Expr }
Expr8 : Ident { AbsGrammar.EVar $1 }
      | Lit { AbsGrammar.ELit $1 }
      | '(' Expr ')' { $2 }
Expr7 :: { Expr }
Expr7 : Expr7 Expr8 { AbsGrammar.EApp $1 $2 } | Expr8 { $1 }
Expr3 :: { Expr }
Expr3 : '-' Expr4 { AbsGrammar.Neg $2 }
      | Expr3 AddOp Expr4 { AbsGrammar.EAdd $1 $2 $3 }
      | Expr4 { $1 }
Expr6 :: { Expr }
Expr6 : '!' Expr7 { AbsGrammar.Not $2 } | Expr7 { $1 }
Expr5 :: { Expr }
Expr5 : Expr6 ':' Expr5 { AbsGrammar.ECons $1 $3 } | Expr6 { $1 }
Expr4 :: { Expr }
Expr4 : Expr4 MulOp Expr5 { AbsGrammar.EMul $1 $2 $3 }
      | Expr5 { $1 }
Expr2 :: { Expr }
Expr2 : Expr2 RelOp Expr3 { AbsGrammar.ERel $1 $2 $3 }
      | Expr3 { $1 }
Expr1 :: { Expr }
Expr1 : Expr2 '&&' Expr1 { AbsGrammar.EAnd $1 $3 } | Expr2 { $1 }
Expr :: { Expr }
Expr : Expr1 '||' Expr { AbsGrammar.EOr $1 $3 }
     | '\\' Bind '->' Expr { AbsGrammar.Lambda $2 $4 }
     | 'let' ListDecl 'in' Expr { AbsGrammar.Let $2 $4 }
     | 'case' Expr2 'of' '{' ListEAlt '}' { AbsGrammar.Case $2 $5 }
     | 'if' Expr 'then' Expr 'else' Expr { AbsGrammar.If $2 $4 $6 }
     | Expr1 { $1 }
ListExpr :: { [Expr] }
ListExpr : {- empty -} { [] }
         | Expr { (:[]) $1 }
         | Expr ',' ListExpr { (:) $1 $3 }
AddOp :: { AddOp }
AddOp : '+' { AbsGrammar.Plus } | '-' { AbsGrammar.Minus }
MulOp :: { MulOp }
MulOp : '*' { AbsGrammar.Times } | '/' { AbsGrammar.Div }
RelOp :: { RelOp }
RelOp : '<' { AbsGrammar.LTH }
      | '<=' { AbsGrammar.LE }
      | '>' { AbsGrammar.GTH }
      | '>=' { AbsGrammar.GE }
      | '==' { AbsGrammar.EQU }
      | '!=' { AbsGrammar.NE }
Decl :: { Decl }
Decl : Ident '::' ETy '=' Expr { AbsGrammar.VDecl $1 $3 $5 }
     | Ident ListIdent '::' ETy '=' Expr { AbsGrammar.FDecl $1 $2 $4 $6 }
     | 'data' Ident ListConstrArg '=' ListConstrDef { AbsGrammar.DDecl $2 (reverse $3) $5 }
ListIdent :: { [Ident] }
ListIdent : Ident { (:[]) $1 } | Ident ListIdent { (:) $1 $2 }
ConstrDef :: { ConstrDef }
ConstrDef : Ident ListConstrArg { AbsGrammar.Constr $1 (reverse $2) }
ConstrArg :: { ConstrArg }
ConstrArg : Ident { AbsGrammar.ConstrArgDef $1 }
ListConstrArg :: { [ConstrArg] }
ListConstrArg : {- empty -} { [] }
              | ListConstrArg ConstrArg { flip (:) $1 $2 }
ListConstrDef :: { [ConstrDef] }
ListConstrDef : ConstrDef { (:[]) $1 }
              | ConstrDef '|' ListConstrDef { (:) $1 $3 }
ListDecl :: { [Decl] }
ListDecl : {- empty -} { [] }
         | Decl { (:[]) $1 }
         | Decl ';' ListDecl { (:) $1 $3 }
ETy2 :: { ETy }
ETy2 : Ident { AbsGrammar.ETVar $1 } | '(' ETy ')' { $2 }
ETy1 :: { ETy }
ETy1 : 'List' ETy1 { AbsGrammar.ETList $2 }
     | ETy2 ETy1 { AbsGrammar.ETApp $1 $2 }
     | 'Bool' { AbsGrammar.ETBool }
     | 'Int' { AbsGrammar.ETInt }
     | ETy2 { $1 }
ETy :: { ETy }
ETy : ETy1 '->' ETy { AbsGrammar.ETArrow $1 $3 } | ETy1 { $1 }
Bind :: { Bind }
Bind : '(' ListBindElem ')' { AbsGrammar.BindMulti $2 }
BindElem :: { BindElem }
BindElem : Ident '::' ETy { AbsGrammar.BindElemT $1 $3 }
ListBindElem :: { [BindElem] }
ListBindElem : BindElem { (:[]) $1 }
             | BindElem ',' ListBindElem { (:) $1 $3 }
EAlt :: { EAlt }
EAlt : ETopPattern '->' Expr { AbsGrammar.EAltCase $1 $3 }
ETopPattern :: { ETopPattern }
ETopPattern : Ident '@' EPattern { AbsGrammar.ETopPatternAt $1 $3 }
            | EPattern { AbsGrammar.ETopPatternNo $1 }
EPattern :: { EPattern }
EPattern : Ident ListEPatConstrArg { AbsGrammar.EPatData $1 $2 }
         | Lit { AbsGrammar.EPatLit $1 }
         | Ident { AbsGrammar.EPatIdent $1 }
         | '_' { AbsGrammar.EPatDefault }
         | Ident ':' EPattern { AbsGrammar.EPatHeadIdent $1 $3 }
         | Lit ':' EPattern { AbsGrammar.EPatHeadLit $1 $3 }
EPatConstrArg :: { EPatConstrArg }
EPatConstrArg : Ident { AbsGrammar.EPatConstrArgDef $1 }
ListEPatConstrArg :: { [EPatConstrArg] }
ListEPatConstrArg : EPatConstrArg { (:[]) $1 }
                  | EPatConstrArg ListEPatConstrArg { (:) $1 $2 }
ListEAlt :: { [EAlt] }
ListEAlt : EAlt { (:[]) $1 } | EAlt ';' ListEAlt { (:) $1 $3 }
{

returnM :: a -> Err a
returnM = return

thenM :: Err a -> (a -> Err b) -> Err b
thenM = (>>=)

happyError :: [Token] -> Err a
happyError ts =
  Bad $ "syntax error at " ++ tokenPos ts ++ 
  case ts of
    [] -> []
    [Err _] -> " due to lexer error"
    t:_ -> " before `" ++ id(prToken t) ++ "'"

myLexer = tokens
}

