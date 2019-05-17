-- Julia Bazińska 385134
-- based on automatically generated file by BNF Converter
module Main where

import System.IO (stdin, hGetContents)
import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure, exitSuccess)
import Control.Monad (when)
import Data.Map.Lazy

import LexGrammar
import ParGrammar
import PrintGrammar
import AbsGrammar

import ErrM
import Interpreter
import Typecheck


asPrintableEnv :: TypeEnv -> Env -> Err [String]
asPrintableEnv tyEnv env = 
  let 
    listEnv = toList env 
    evalLazyExpr (ident, envVal) =
        case envVal of 
            LazyVal expr lazyEnv -> evalExpr lazyEnv expr >>= \val -> return (ident, val)
            AlreadyVal val -> return (ident, val)
  in
  mapM evalLazyExpr listEnv
    >>= \lst -> return (Prelude.map (\(id@(Ident ident), val) -> ident ++ " :: " ++ (show $ tyEnv ! id) ++ " = " ++ (show val)) lst)


interpret :: String -> IO ()
interpret s = 
    let 
        result = (pProg $ myLexer s) 
            >>= (\p -> typeProg p 
                >>= (\tyEnv -> transProg p 
                    >>= asPrintableEnv tyEnv)) 
    in
    case result of 
        Ok results -> mapM_ putStrLn results
        Bad errString -> putStrLn $ "ERROR: " ++ errString

runFile :: FilePath -> IO ()
runFile f = readFile f >>= interpret


main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> getContents >>= interpret
    fs -> mapM_ (runFile) fs
