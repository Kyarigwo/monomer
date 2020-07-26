{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards #-}

module Monomer.Main.Core (
  EventResponse(..),
  createApp,
  runWidgets
) where

import Control.Concurrent (threadDelay)
import Control.Lens
import Control.Monad
import Control.Monad.Extra
import Control.Monad.IO.Class
import Control.Monad.State
import Data.List (foldl')
import Data.Maybe
import Data.Sequence (Seq, (><))
import Data.Text (Text)
import Data.Typeable (Typeable)

import qualified Data.Map as M
import qualified Graphics.Rendering.OpenGL as GL
import qualified SDL
import qualified Data.Sequence as Seq
import qualified NanoVG as NV

import Monomer.Common.Geometry
import Monomer.Event.Core
import Monomer.Event.Types
import Monomer.Event.Util
import Monomer.Main.Handlers
import Monomer.Main.Platform
import Monomer.Main.Types
import Monomer.Main.Util
import Monomer.Main.WidgetTask
import Monomer.Graphics.NanoVGRenderer
import Monomer.Graphics.Renderer
import Monomer.Widget.CompositeWidget
import Monomer.Widget.Types
import Monomer.Widget.Util

data MainLoopArgs s e = MainLoopArgs {
  _mlPlatform :: WidgetPlatform,
  _mlAppStartTs :: Int,
  _mlFrameStartTs :: Int,
  _mlFrameAccumTs :: Int,
  _mlFrameCount :: Int,
  _mlWidgetRoot :: WidgetInstance s e
}

createApp
  :: (Eq s, Typeable s, Typeable e)
  => s
  -> Maybe e
  -> EventHandler s e ()
  -> UIBuilder s e
  -> WidgetInstance () ()
createApp model initEvent eventHandler uiBuilder = app where
  app = composite "app" model initEvent eventHandler uiBuilder

createWidgetPlatform :: (Monad m) => Text -> Renderer m -> WidgetPlatform
createWidgetPlatform os renderer = WidgetPlatform {
  _wpOS = os,
  _wpGetKeyCode = getKeyCode,
  _wpTextBounds = textBounds renderer
}

runWidgets
  :: (MonomerM s m) => SDL.Window -> NV.Context -> WidgetInstance s e -> m ()
runWidgets window c widgetRoot = do
  useHiDPI <- use useHiDPI
  devicePixelRate <- use devicePixelRate
  Size rw rh <- use windowSize

  let dpr = if useHiDPI then devicePixelRate else 1
  let newWindowSize = Size (rw / dpr) (rh / dpr)

  windowSize .= newWindowSize
  startTs <- fmap fromIntegral SDL.ticks
  ctx <- get
  model <- use mainModel
  os <- getPlatform
  renderer <- makeRenderer c dpr
  let widgetPlatform = createWidgetPlatform os renderer
  let wenv = WidgetEnv {
    _wePlatform = widgetPlatform,
    _weScreenSize = newWindowSize,
    _weGlobalKeys = M.empty,
    _weFocusedPath = rootPath,
    _weModel = model,
    _weInputStatus = defInputStatus,
    _weTimestamp = startTs
  }
  let pathReadyRoot = widgetRoot {
    _instancePath = Seq.singleton 0
  }
  (newWenv, _, initializedRoot) <- handleWidgetInit renderer wenv pathReadyRoot

  let resizedRoot = resizeWidget newWenv newWindowSize initializedRoot
  let loopArgs = MainLoopArgs {
    _mlPlatform = widgetPlatform,
    _mlAppStartTs = 0,
    _mlFrameStartTs = startTs,
    _mlFrameAccumTs = 0,
    _mlFrameCount = 0,
    _mlWidgetRoot = resizedRoot
  }

  mainModel .= _weModel newWenv
  focused .= findNextFocusable newWenv rootPath resizedRoot

  mainLoop window c renderer loopArgs

mainLoop
  :: (MonomerM s m)
  => SDL.Window
  -> NV.Context
  -> Renderer m
  -> MainLoopArgs s e
  -> m ()
mainLoop window c renderer loopArgs = do
  windowSize <- use windowSize
  useHiDPI <- use useHiDPI
  devicePixelRate <- use devicePixelRate
  startTicks <- fmap fromIntegral SDL.ticks
  events <- SDL.pollEvents
  mousePos <- getCurrentMousePos
  currentModel <- use mainModel
  focused <- use focused
  oldInputStatus <- use inputStatus

  let MainLoopArgs{..} = loopArgs
  let !ts = startTicks - _mlFrameStartTs
  let eventsPayload = fmap SDL.eventPayload events
  let quit = SDL.QuitEvent `elem` eventsPayload
  let resized = not $ null [ e | e@SDL.WindowResizedEvent {} <- eventsPayload ]
  let mouseEntered =
        not $ null [ e | e@SDL.WindowGainedMouseFocusEvent {} <- eventsPayload ]
  let mousePixelRate = if not useHiDPI then devicePixelRate else 1
  let baseSystemEvents = convertEvents mousePixelRate mousePos eventsPayload
  let newSecond = _mlFrameStartTs + ts > 1000
  let oldWenv = WidgetEnv {
    _wePlatform = _mlPlatform,
    _weScreenSize = windowSize,
    _weGlobalKeys = M.empty,
    _weFocusedPath = focused,
    _weModel = currentModel,
    _weInputStatus = oldInputStatus,
    _weTimestamp = startTicks
  }

  --when newSecond $
  --  liftIO . putStrLn $ "Frames: " ++ (show frames)

  sysEvents <- preProcessEvents oldWenv _mlWidgetRoot baseSystemEvents
  inputStatus <- use inputStatus
  isMouseFocused <- fmap isJust (use latestPressed)

  let isLeftPressed = isButtonPressed inputStatus LeftBtn
  let wenv = oldWenv {
    _weInputStatus = oldInputStatus
  }

  when (mouseEntered && isLeftPressed && isMouseFocused) $
    latestPressed .= Nothing

  (wtWenv, _, wtRoot) <- handleWidgetTasks renderer wenv _mlWidgetRoot
  (seWenv, _, seRoot) <- handleSystemEvents renderer wtWenv sysEvents wtRoot

  newRoot <- if resized then resizeWindow window seWenv seRoot
                              else return seRoot

  renderWidgets window c renderer seWenv newRoot
  runOverlays renderer

  endTicks <- fmap fromIntegral SDL.ticks

  let fps = 30
  let frameLength = 0.9 * 1000000 / fps
  let newTs = fromIntegral $ endTicks - startTicks
  let nextFrameDelay = round . abs $ (frameLength - newTs * 1000)
  let newLoopArgs = loopArgs {
    _mlAppStartTs = _mlAppStartTs + ts,
    _mlFrameStartTs = startTicks,
    _mlFrameAccumTs = if newSecond then 0 else _mlFrameAccumTs + ts,
    _mlFrameCount = if newSecond then 0 else _mlFrameCount + 1,
    _mlWidgetRoot = newRoot
  }

  liftIO $ threadDelay nextFrameDelay
  unless quit (mainLoop window c renderer newLoopArgs)

renderWidgets
  :: (MonomerM s m)
  => SDL.Window
  -> NV.Context
  -> Renderer m
  -> WidgetEnv s e
  -> WidgetInstance s e
  -> m ()
renderWidgets !window !c !renderer wenv widgetRoot =
  doInDrawingContext window c $
    _widgetRender (_instanceWidget widgetRoot) renderer wenv widgetRoot

resizeWindow
  :: (MonomerM s m)
  => SDL.Window
  -> WidgetEnv s e
  -> WidgetInstance s e
  -> m (WidgetInstance s e)
resizeWindow window wenv widgetRoot = do
  dpr <- use devicePixelRate
  drawableSize <- getDrawableSize window
  newWindowSize <- getWindowSize window dpr

  let position = GL.Position 0 0
  let size = GL.Size (round $ _w drawableSize) (round $ _h drawableSize)

  windowSize .= newWindowSize
  liftIO $ GL.viewport GL.$= (position, size)

  return $ resizeWidget wenv newWindowSize widgetRoot

-- Pre process events (change focus, add Enter/Leave events, etc)
preProcessEvents
  :: (MonomerM s m)
  => WidgetEnv s e -> WidgetInstance s e -> [SystemEvent] -> m [SystemEvent]
preProcessEvents wenv widgets events = do
  systemEvents <- concatMapM (preProcessEvent wenv widgets) events
  mapM_ updateInputStatus systemEvents
  return systemEvents

preProcessEvent
  :: (MonomerM s m)
  => WidgetEnv s e -> WidgetInstance s e -> SystemEvent -> m [SystemEvent]
preProcessEvent wenv widgetRoot evt@(Move point) = do
  hover <- use latestHover
  let widget = _instanceWidget widgetRoot
  let current = _widgetFind widget wenv rootPath point widgetRoot
  let hoverChanged = isJust hover && current /= hover
  let enter = [Enter point | isNothing hover || hoverChanged]
  let leave = [Leave (fromJust hover) point | hoverChanged]

  when (isNothing hover || hoverChanged) $
    latestHover .= current

  return $ leave ++ enter ++ [evt]
preProcessEvent wenv widgetRoot evt@(ButtonAction point btn PressedBtn) = do
  let widget = _instanceWidget widgetRoot
  let current = _widgetFind widget wenv rootPath point widgetRoot

  latestPressed .= current
  return [evt]
preProcessEvent wenv widgetRoot evt@(ButtonAction point btn ReleasedBtn) = do
  latestPressed .= Nothing
  return [Click point btn, evt]

preProcessEvent wenv widgetRoot event = return [event]

updateInputStatus :: (MonomerM s m) => SystemEvent -> m ()
updateInputStatus (Move point)
  = inputStatus %= \status -> status {
    statusMousePos = point
  }
updateInputStatus (ButtonAction _ btn btnState)
  = inputStatus %= \status -> status {
    statusButtons = M.insert btn btnState (statusButtons status)
  }
updateInputStatus (KeyAction kMod kCode kStatus)
  = inputStatus %= \status -> status {
    statusKeyMod = kMod,
    statusKeys = M.insert kCode kStatus (statusKeys status)
  }
updateInputStatus _ = return ()
