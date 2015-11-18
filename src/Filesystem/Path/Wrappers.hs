{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Filesystem.Path.Wrappers where

import ClassyPrelude hiding (FilePath, unpack, (</>), readFile)
import qualified ClassyPrelude as CP
import Data.Text hiding (map)
import qualified Data.Text as T
import System.Directory (Permissions(..))
import qualified System.Directory as Dir
import qualified System.Posix.Files as Posix
import Filesystem.Path.CurrentOS
import Control.Monad.Trans.Control
import Control.Exception.Lifted
import qualified Paths_nixfromnpm as Paths

import qualified Nix.Types as Nix

-- | Take a function that takes a string path and returns something, and
-- turn it into a function that operates in any MonadIO and takes a FilePath.
generalize :: MonadIO io => (CP.FilePath -> IO a) -> FilePath -> io a
generalize action = liftIO . action . pathToString

-- | Makes a nix regular path expression from a filepath.
mkPath :: FilePath -> Nix.NExpr
mkPath = Nix.mkPath False . pathToString

-- | Makes a nix regular path expression from a filepath.
mkEnvPath :: FilePath -> Nix.NExpr
mkEnvPath = Nix.mkPath True . pathToString

-- | Wraps a function generated by cabal. Returns path to a data file.
getDataFileName :: MonadIO io => FilePath -> io FilePath
getDataFileName = map decodeString . generalize Paths.getDataFileName

-- | Write some stuff to disk.
writeFile :: (MonadIO io, IOData dat) => FilePath -> dat -> io ()
writeFile path = CP.writeFile (pathToString path)

-- | Read a file from disk.
readFile :: (MonadIO io, IOData dat) => FilePath -> io dat
readFile = generalize CP.readFile

-- | Read a data file, as included by cabal.
readDataFile :: (MonadIO io, IOData dat) => FilePath -> io dat
readDataFile = getDataFileName >=> readFile

-- | Create a symbolic link at `path2` pointing to `path1`.
createSymbolicLink :: (MonadIO io) => FilePath -> FilePath -> io ()
createSymbolicLink path1 path2 = liftIO $ do
  Posix.createSymbolicLink (pathToString path1) (pathToString path2)

-- | Convert a FilePath into Text.
pathToText :: FilePath -> Text
pathToText pth = case toText pth of
  Left p -> p
  Right p -> p

-- | Convert a FilePath into a string.
pathToString :: FilePath -> String
pathToString = unpack . pathToText

-- | Get the contents of a directory, with the directory prepended.
listDirFullPaths :: MonadIO io => FilePath -> io [FilePath]
listDirFullPaths dir = map (dir </>) <$> getDirectoryContents dir

-- | Map an action over each item in the directory. The action will be
-- called with the path to the directory prepended to the item.
forItemsInDir :: MonadIO io => FilePath -> (FilePath -> io a) -> io [a]
forItemsInDir dir action = do
  paths <- listDirFullPaths dir
  forM paths action

-- | Map an action over each item in the directory, and ignore the results.
forItemsInDir_ :: MonadIO io => FilePath -> (FilePath -> io ()) -> io ()
forItemsInDir_ dir action = do
  paths <- listDirFullPaths dir
  forM_ paths action

-- | Get the base name (filename) of a path, as text.
getFilename :: FilePath -> Text
getFilename = pathToText . filename

-- | Get the base name of a path without extension, as text.
getBaseName :: FilePath -> Text
getBaseName = pathToText . fst . splitExtension . filename

createDirectory :: MonadIO io => FilePath -> io ()
createDirectory = generalize Dir.createDirectory

copyFile :: MonadIO io => FilePath -> FilePath -> io ()
copyFile source target = liftIO $ Dir.copyFile (pathToString source)
                                               (pathToString target)

createDirectoryIfMissing :: MonadIO m => FilePath -> m ()
createDirectoryIfMissing = liftIO . Dir.createDirectoryIfMissing True .
                             pathToString

doesDirectoryExist :: MonadIO m => FilePath -> m Bool
doesDirectoryExist = liftIO . Dir.doesDirectoryExist . pathToString

doesFileExist :: MonadIO m => FilePath -> m Bool
doesFileExist = liftIO . Dir.doesFileExist . pathToString

doesPathExist :: MonadIO m => FilePath -> m Bool
doesPathExist path = doesFileExist path >>= \case
  True -> return True
  False -> doesDirectoryExist path

getCurrentDirectory :: MonadIO m => m FilePath
getCurrentDirectory = decodeString <$> liftIO Dir.getCurrentDirectory

removeDirectoryRecursive :: MonadIO m => FilePath -> m ()
removeDirectoryRecursive = liftIO . Dir.removeDirectoryRecursive . pathToString

removeFile :: MonadIO m => FilePath -> m ()
removeFile = liftIO . Dir.removeFile . pathToString

getDirectoryContents :: MonadIO m => FilePath -> m [FilePath]
getDirectoryContents dir = do
  contents <- liftIO $ Dir.getDirectoryContents $ pathToString dir
  -- Filter out the '.' and '..' folders.
  let noDots p = let fn = getFilename p in fn /= "" && T.head fn /= '.'
  return $ CP.filter noDots $ map decodeString contents

hasExt :: Text -> FilePath -> Bool
hasExt ext path = case extension path of
  Just ext' | ext == ext' -> True
  otherwise -> False

setCurrentDirectory :: MonadIO io => FilePath -> io ()
setCurrentDirectory = liftIO . Dir.setCurrentDirectory . pathToString

getPermissions :: MonadIO io => FilePath -> io Permissions
getPermissions = generalize Dir.getPermissions

isWritable :: MonadIO io => FilePath -> io Bool
isWritable = map writable . getPermissions

absPath :: MonadIO io => FilePath -> io FilePath
absPath path = (</> path) <$> getCurrentDirectory

isDirectoryEmpty :: MonadIO io => FilePath -> io Bool
isDirectoryEmpty = map CP.null . getDirectoryContents
