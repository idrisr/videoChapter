{-# LANGUAGE OverloadedStrings #-}

module VideoChapter.Model
    ( Chapter (..)
    , Media (..)
    , chapterTime
    , chapterTitle
    , formatTimeText
    , mediaChapters
    )
where

import Data.Aeson (FromJSON (..), withObject, (.:))
import Data.List (nub)
import Data.Map (toList)
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe)
import Data.Text (Text, split, toLower, unpack)
import Data.Time.Clock (NominalDiffTime)
import Fmt (Buildable (build), Builder, blockListF, fmt, padRightF, pretty, timeF, (+|), (|+))
import Text.Read (readMaybe)

newtype Media = Media {track :: [Track]}
    deriving (Show)

data Audio = Audio deriving (Show)
newtype Video = Video {duration :: String} deriving (Show)
data General = General deriving (Show)
data Text_ = Text_ deriving (Show)
data Chapter = Chapter Text (Maybe NominalDiffTime)
    deriving (Show, Eq)

newtype Menu = Menu {chapters :: [Chapter]} deriving (Show)

data Track = GeneralTr General | MenuTr Menu | VideoTr Video | AudioTr Audio | TextTr Text_
    deriving (Show)

instance Buildable Media where
    build (Media tracks) =
        formatTime (fromMaybe 0 parseDuration) +| ("\n\n" :: Text) |+ blockListF menu +| ""
      where
        menu = mediaChapters (Media tracks)
        parseDuration :: Maybe NominalDiffTime
        parseDuration = do
            let ts = mapMaybe toVideo tracks
            (Video s) <- listToMaybe ts
            t <- readMaybe s :: Maybe Double
            pure . realToFrac $ t

instance Buildable Video where
    build (Video d) = pretty d

instance Buildable Chapter where
    build (Chapter title mTime) =
        padRightF 10 ' ' (maybe "" formatTime mTime) +| toLower title |+ ""

formatTime :: NominalDiffTime -> Builder
formatTime s | s < 3600 = timeF "%02M:%02S" s
formatTime s = timeF "%02H:%02M:%02S" s

formatTimeText :: NominalDiffTime -> Text
formatTimeText = fmt . formatTime

instance FromJSON Media where
    parseJSON = withObject "root" $ \v -> do
        mediaObj <- v .: "media"
        ts <- mediaObj .: "track"
        pure $ Media ts

instance FromJSON Track where
    parseJSON = withObject "track" $ \v -> do
        t <- v .: "@type"
        case t of
            "General" -> pure $ GeneralTr General
            "Video" -> do
                e <- v .: "Duration"
                pure $ VideoTr $ Video e
            "Audio" -> pure $ AudioTr Audio
            "Text" -> pure $ TextTr Text_
            "Menu" -> do
                e <- v .: "extra"
                pure . MenuTr . Menu $ uncurry toChapter <$> toList e
            _ -> fail $ "no good" <> t

readTimeStamp :: Text -> Maybe NominalDiffTime
readTimeStamp stamp =
    let xs = split ('_' ==) stamp
     in if length xs == 5
            then
                let
                    hours :: Maybe Integer
                    hours = readMaybe . unpack $ xs !! 1
                    mins = readMaybe . unpack $ xs !! 2
                    secs = readMaybe . unpack $ xs !! 3
                    timeSum h m s = h * 3600 + m * 60 + s
                 in
                    fromIntegral <$> (timeSum <$> hours <*> mins <*> secs)
            else Nothing

toChapter :: Text -> Text -> Chapter
toChapter k v = Chapter v (readTimeStamp k)

mediaChapters :: Media -> [Chapter]
mediaChapters (Media tracks) = nub $ concatMap chapters (mapMaybe toMenu tracks)

chapterTitle :: Chapter -> Text
chapterTitle (Chapter title _) = title

chapterTime :: Chapter -> Maybe NominalDiffTime
chapterTime (Chapter _ mTime) = mTime

toMenu :: Track -> Maybe Menu
toMenu (MenuTr m) = Just m
toMenu _ = Nothing

toVideo :: Track -> Maybe Video
toVideo (VideoTr v) = Just v
toVideo _ = Nothing
