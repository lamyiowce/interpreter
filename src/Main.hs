-- Julia Bazińska 385134
-- based on automatically generated file by BNF Converter
module Main where

import System.IO ( stdin, hGetContents )
import System.Environment ( getArgs, getProgName )
import System.Exit ( exitFailure, exitSuccess )
import Control.Monad (when)

import LexGrammar
import ParGrammar
import SkelGrammar
import PrintGrammar
import AbsGrammar

import ErrM

type ParseFun a = [Token] -> Err a


showTree :: (Show a, Print a) =>  a -> IO ()
showTree tree = do
      putStrLn $ "\n[Abstract Syntax]\n\n" ++ show tree
      putStrLn $ "\n[Linearized tree]\n\n" ++ printTree tree

runFile :: (Print a, Show a) => ParseFun a -> FilePath -> IO ()
runFile p f = readFile f >>= run p

run :: (Print a, Show a) => ParseFun a -> String -> IO ()
run p s = let ts = myLexer s in case p ts of
           Bad s    -> do putStrLn $ show ts
                          exitFailure
           Ok  tree -> do putStrLn "\nParse Successful!"
                          showTree tree
                          interpret tree
                          exitSuccess

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> putStrLn "Please provide a path to file."
    fs -> mapM_ (runFile pProg) fs





