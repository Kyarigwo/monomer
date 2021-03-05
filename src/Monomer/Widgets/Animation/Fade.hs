{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Monomer.Widgets.Animation.Fade (
  fadeIn,
  fadeIn_,
  fadeOut,
  fadeOut_
) where

import Codec.Serialise
import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Lens ((&), (^.), (.~), (%~), at)
import Control.Monad (when)
import Data.Default
import Data.Maybe
import Data.Typeable (Typeable, cast)
import GHC.Generics

import qualified Data.Sequence as Seq

import Monomer.Widgets.Container
import Monomer.Widgets.Animation.Types

import qualified Monomer.Lens as L

data FadeCfg e = FadeCfg {
  _fdcAutoStart :: Maybe Bool,
  _fdcDuration :: Maybe Int,
  _fdcOnFinished :: [e]
} deriving (Eq, Show)

instance Default (FadeCfg e) where
  def = FadeCfg {
    _fdcAutoStart = Nothing,
    _fdcDuration = Nothing,
    _fdcOnFinished = []
  }

instance Semigroup (FadeCfg e) where
  (<>) fc1 fc2 = FadeCfg {
    _fdcAutoStart = _fdcAutoStart fc2 <|> _fdcAutoStart fc1,
    _fdcDuration = _fdcDuration fc2 <|> _fdcDuration fc1,
    _fdcOnFinished = _fdcOnFinished fc1 <> _fdcOnFinished fc2
  }

instance Monoid (FadeCfg e) where
  mempty = def

instance CmbAutoStart (FadeCfg e) where
  autoStart_ start = def {
    _fdcAutoStart = Just start
  }

instance CmbDuration (FadeCfg e) Int where
  duration dur = def {
    _fdcDuration = Just dur
  }

instance CmbOnFinished (FadeCfg e) e where
  onFinished fn = def {
    _fdcOnFinished = [fn]
  }

data FadeState = FadeState {
  _fdsRunning :: Bool,
  _fdsStartTs :: Int
} deriving (Eq, Show, Generic, Serialise)

instance Default FadeState where
  def = FadeState {
    _fdsRunning = False,
    _fdsStartTs = 0
  }

instance WidgetModel FadeState where
  modelToByteString = serialise
  byteStringToModel = bsToSerialiseModel

fadeIn :: WidgetNode s e -> WidgetNode s e
fadeIn managed = fadeIn_ def managed

fadeIn_ :: [FadeCfg e] -> WidgetNode s e -> WidgetNode s e
fadeIn_ configs managed = makeNode widget managed where
  config = mconcat configs
  widget = makeFade True config def

fadeOut :: WidgetNode s e -> WidgetNode s e
fadeOut managed = fadeOut_ def managed

fadeOut_ :: [FadeCfg e] -> WidgetNode s e -> WidgetNode s e
fadeOut_ configs managed = makeNode widget managed where
  config = mconcat configs
  widget = makeFade False config def

makeNode :: Widget s e -> WidgetNode s e -> WidgetNode s e
makeNode widget managedWidget = defaultWidgetNode "fadeIn" widget
  & L.info . L.focusable .~ False
  & L.children .~ Seq.singleton managedWidget

makeFade :: Bool -> FadeCfg e -> FadeState -> Widget s e
makeFade isFadeIn config state = widget where
  widget = createContainer state def {
    containerInit = init,
    containerRestore = restore,
    containerHandleMessage = handleMessage,
    containerRender = render,
    containerRenderAfter = renderPost
  }

  FadeState running start = state
  autoStart = fromMaybe False (_fdcAutoStart config)
  duration = fromMaybe 2000 (_fdcDuration config)
  period = 20
  steps = duration `div` period

  finishedReq node = delayMessage node AnimationFinished duration
  renderReq wenv node = req where
    widgetId = node ^. L.info . L.widgetId
    req = RenderEvery widgetId period (Just steps)

  init wenv node = result where
    ts = wenv ^. L.timestamp
    newNode = node
      & L.widget .~ makeFade isFadeIn config (FadeState True ts)
    result
      | autoStart = resultReqs newNode [finishedReq node, renderReq wenv node]
      | otherwise = resultWidget node

  restore wenv oldState oldInfo node = resultWidget newNode where
    newNode = node
      & L.widget .~ makeFade isFadeIn config oldState

  handleMessage wenv target message node = result where
    result = cast message >>= Just . handleAnimateMsg wenv node

  handleAnimateMsg wenv node msg = result where
    widgetId = node ^. L.info . L.widgetId
    ts = wenv ^. L.timestamp
    startState = FadeState True ts
    startReqs = [finishedReq node, renderReq wenv node]
    newNode newState = node
      & L.widget .~ makeFade isFadeIn config newState
    result = case msg of
      AnimationStart -> resultReqs (newNode startState) startReqs
      AnimationStop -> resultReqs (newNode def) [RenderStop widgetId]
      AnimationFinished
        | _fdsRunning state -> resultEvts (newNode def) (_fdcOnFinished config)
        | otherwise -> resultWidget (newNode def)

  render renderer wenv node = do
    saveContext renderer
    when running $
      setGlobalAlpha renderer alpha
    where
      ts = wenv ^. L.timestamp
      currStep = clampAlpha $ fromIntegral (ts - start) / fromIntegral duration
      alpha
        | isFadeIn = currStep
        | otherwise = 1 - currStep

  renderPost renderer wenv node = do
    restoreContext renderer

delayMessage :: Typeable i => WidgetNode s e -> i -> Int -> WidgetRequest s
delayMessage node msg delay = RunTask widgetId path $ do
  threadDelay (delay * 1000)
  return msg
  where
    widgetId = node ^. L.info . L.widgetId
    path = node ^. L.info . L.path