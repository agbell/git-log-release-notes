{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE NoMonomorphismRestriction #-}

import Data.Word
import Data.Time
import Data.Attoparsec.Text
import Data.Attoparsec.Combinator
import qualified Data.Attoparsec.Text as Parse
import qualified Data.Attoparsec.Combinator as Parse 
import qualified Data.Attoparsec.ByteString.Char8 as BParse
import Control.Applicative
import Data.Either (rights)
import Data.Monoid hiding (Product)
import Data.String
import Data.Foldable (foldMap)
import Data.Text as T
-- ByteString stuff
import Data.ByteString.Char8 (ByteString,singleton)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import Data.ByteString.Lazy (toChunks)

import Text.Hastache 
import Text.Hastache.Context 
import qualified Data.Text.Lazy as TL1 
import qualified Data.Text.Lazy.IO as TL 
import Data.Text.Lazy.Encoding as TE
import Data.Data 
import Data.Generics 
import Data.Char
import Control.Monad
import Data.Map
import qualified Data.Map as Map
-----------------------
-------- TYPES --------
-----------------------
data Date = Date { year :: Int, month :: Int, day :: Int} deriving (Eq,Show, Data, Typeable)
data Version = Version { major :: Int, minor :: Int, build :: Int, revision :: Int} deriving (Eq,Show, Data, Typeable, Ord)
data Note = Note { version :: Version, date :: Date, description :: Text } deriving (Eq,Show, Data, Typeable)

instance Ord Note where
  n1 <= n2 = version n1 <= version n2

instance Ord Date where
  compare  d1 d2 = compare (year d1) (year d2) 
    <> compare (month d1) (month d2)
    <> compare (day d1) (day d2)

data Notes = Notes { notes :: [Note] } deriving (Data, Typeable, Show)

toNotes :: [Note] ->  Map Version Note
toNotes ns = Map.fromList $ toPair <$> ns
 where
     toPair n@(Note v _ _) = (v,n)

toNoteList ::  Map Version Note -> [Note]
toNoteList n = Map.elems n

----------------------
------- FILES --------
----------------------

data File = Local FilePath

-- | Files where the logs are stored.
--   Modify this value to read logs from
--   other sources.
logFiles :: [File]
logFiles =
  [ Local "log.txt"
    ]

getFile :: File -> IO Text
getFile (Local fp) = TL1.toStrict <$> TL.readFile fp


-----------------------
------- PARSING -------
-----------------------
anyBetween start ends = start *> Data.Attoparsec.Text.takeWhile (not.flip elem ends)
fromUptoIncl startP endChars = startP *> takeTill (flip elem endChars)

dateParser :: Parser Date
dateParser = do
  y  <- Parse.count 4 digit
  char '-'
  mm <- Parse.count 2 digit
  char '-'
  d  <- Parse.count 2 digit
  return $
    Date (read y) (read mm) (read d)

versionParser :: Parser Version
versionParser = do
    header <- asciiCI "(tag: VCH"
    major <- Parse.takeWhile BParse.isDigit
    char '.'
    minor <- Parse.takeWhile BParse.isDigit
    char '.'
    build <- Parse.takeWhile BParse.isDigit
    char '.'
    revision <- Parse.takeWhile BParse.isDigit
    return $ Version (read . unpack $ major) (read . unpack $  minor) (read . unpack $ build) (read . unpack $ revision)


messageParser :: Parser Text
messageParser = 
    skipWhile (/= '|') 
    *> skip (== '|') 
    *> takeTill isEndOfLine


noteParser :: Parser Note
noteParser = do
  d <- dateParser
  string "| "
  v <- versionParser
  s <- messageParser
  return $ Note v d s

notesParser :: Parser [Note]
notesParser = many1 $ noteParser <* endOfLine

-- Test Parse
testDate = print $ parseOnly dateParser "2013-06-30"

testVersion = print $ parseOnly versionParser "(tag: VCH3.0.10.206(default))"
   
testNotes = print $ parseOnly notesParser "2014-04-17| (tag: VCH3.0.10.206(default))|Subject Line\n2014-04-17| (tag: VCH3.0.10.206(default))|Subject Line\n"

-----------------------
------- MERGING -------
-----------------------

merge :: Ord a => [a] -> [a] -> [a]
merge xs [] = xs
merge [] ys = ys
merge (x:xs) (y:ys) =
  if x <= y
     then x : merge xs (y:ys)
     else y : merge (x:xs) ys


fromRight (Right a) = a


----------------------
-------- MAIN --------
----------------------

main = testNotes
-- printTemplate
--    testNotes
--    fileMain

parseNote :: [Text] -> [Note]
parseNote txt = join . rights $ fmap (parseOnly notesParser) txt

getLogFiles :: [File] -> IO [Text]
getLogFiles xs = mapM getFile xs


fileMain = do
  files <- getLogFiles logFiles
  let
      logs :: Notes
      logs = Notes $ parseNote files
      context =  mkGenericContext logs
      render = hastacheFile defaultConfig
  x <- render "note.html" context 
  print $ show logs
  TL.putStrLn . TE.decodeUtf8 $ x
  TL.putStrLn "bye"

printTemplate = hastacheFile defaultConfig template parsedContext
 >>= TL.putStrLn . TE.decodeUtf8

-- begin example
template = "note.html"

simpleContext = mkGenericContext $ Notes [
    Note { version= Version 3 10 0 127, date= Date 2014 03 02 ,  description = "Added Transfer of data from existing web.configs to new web.configs, this means we can push a new web.config as part of the update."},
    Note { version= Version 3 10 0 129, date= Date 2014 03 01 ,  description = "Added spinner to all ajax requests"}
    ]

parsedContext =   mkGenericContext $ join .rights $ fmap (parseOnly notesParser) "2014-04-17| (tag: VCH3.0.10.206(default))|Subject Line\n2014-04-17| (tag: VCH3.0.10.206(default))|Subject Line"

