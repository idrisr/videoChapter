{-# LANGUAGE OverloadedStrings #-}

module VideoChapter.Srt
    ( SrtEntry (..)
    , parseSrtEntries
    )
where

import Data.Char (isDigit)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (NominalDiffTime)
import Text.Read (readMaybe)

data SrtEntry = SrtEntry
    { srtStart :: NominalDiffTime
    , srtEnd :: NominalDiffTime
    , srtText :: Text
    }
    deriving (Show, Eq)

parseSrtEntries :: Text -> [SrtEntry]
parseSrtEntries input = go (Text.lines input)
  where
    go [] = []
    go (line : rest)
        | Text.null (Text.strip line) = go rest
        | Text.all isDigit (Text.strip line) = go rest
        | otherwise =
            case parseSrtTimeLine line of
                Just (startTime, endTime) ->
                    let (textLines, remaining) = break (Text.null . Text.strip) rest
                        text = Text.strip . Text.unwords $ map Text.strip textLines
                     in case Text.null text of
                            True -> go remaining
                            False -> SrtEntry startTime endTime text : go remaining
                Nothing -> go rest

parseSrtTimeLine :: Text -> Maybe (NominalDiffTime, NominalDiffTime)
parseSrtTimeLine line = do
    let (left, rightWithArrow) = Text.breakOn "-->" line
    if Text.null rightWithArrow
        then Nothing
        else do
            let right = Text.drop (Text.length "-->") rightWithArrow
            startTime <- parseSrtTimestamp (Text.strip left)
            endTime <- parseSrtTimestamp (Text.strip right)
            pure (startTime, endTime)

parseSrtTimestamp :: Text -> Maybe NominalDiffTime
parseSrtTimestamp raw =
    case Text.splitOn ":" (Text.strip raw) of
        [hoursText, minsText, secsText] -> parseParts hoursText minsText secsText
        [minsText, secsText] -> parseParts "0" minsText secsText
        _ -> Nothing
  where
    parseParts hoursText minsText secsText = do
        hours <- readMaybe (Text.unpack hoursText) :: Maybe Integer
        mins <- readMaybe (Text.unpack minsText) :: Maybe Integer
        (secs, millis) <- parseSeconds secsText
        let totalSeconds =
                fromIntegral hours * 3600
                    + fromIntegral mins * 60
                    + secs
                    + millis / 1000
        pure (realToFrac totalSeconds)

parseSeconds :: Text -> Maybe (Double, Double)
parseSeconds raw = do
    let (secsText, millisText) = splitSeconds raw
    secs <- readMaybe (Text.unpack secsText) :: Maybe Double
    millis <- case millisText of
        Nothing -> pure 0
        Just msText -> readMaybe (Text.unpack msText) :: Maybe Double
    pure (secs, millis)

splitSeconds :: Text -> (Text, Maybe Text)
splitSeconds raw =
    case Text.splitOn "," raw of
        [secsText, millisText] -> (secsText, Just millisText)
        [secsText] ->
            case Text.splitOn "." raw of
                [secsText', millisText] -> (secsText', Just millisText)
                _ -> (secsText, Nothing)
        _ -> (raw, Nothing)
