{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Monomer.Widgets.Animation.FadeSpec (spec) where

import Control.Lens ((&), (^.), (.~), (?~), (^?!), _1, _3, ix)
import Data.Default
import Data.Text (Text)
import Test.Hspec

import qualified Data.Sequence as Seq

import Monomer.Core
import Monomer.Core.Combinators
import Monomer.Event
import Monomer.TestUtil
import Monomer.TestEventUtil
import Monomer.Widgets.Animation.Fade
import Monomer.Widgets.Animation.Types
import Monomer.Widgets.Containers.Stack
import Monomer.Widgets.Containers.Scroll
import Monomer.Widgets.Singles.Label

import qualified Monomer.Lens as L

data TestEvt
  = OnTestFinished
  deriving (Eq, Show)

spec :: Spec
spec = describe "Fade" $ do
  initWidget
  handleMessage
  getSizeReq

initWidget :: Spec
initWidget = describe "initWidget" $ do
  it "should not request rendering if autoStart = False" $
    reqs nodeNormal `shouldBe` Seq.empty

  it "should request rendering if autoStart = True" $ do
    reqs nodeAuto ^?! ix 0 `shouldSatisfy` isRunTask
    reqs nodeAuto ^?! ix 1 `shouldSatisfy` isRenderEvery

  where
    wenv = mockWenvEvtUnit ()
    nodeNormal = fadeIn (label "Test")
    nodeAuto = fadeIn_ [autoStart, duration 100] (label "Test")
    reqs node = nodeHandleEvents_ wenv WInit [] node ^?! ix 0 . _1 . _3

handleMessage :: Spec
handleMessage = describe "handleMessage" $ do
  it "should not request rendering if an invalid message is received" $
    reqs ScrollReset `shouldBe` Seq.empty

  it "should request rendering if AnimationStart is received" $ do
    reqs AnimationStart ^?! ix 0 `shouldSatisfy` isRunTask
    reqs AnimationStart ^?! ix 1 `shouldSatisfy` isRenderEvery
    evts AnimationStart `shouldBe` Seq.empty

  it "should cancel rendering if AnimationStop is received" $ do
    reqs AnimationStop ^?! ix 0 `shouldSatisfy` isRenderStop
    evts AnimationStop `shouldBe` Seq.empty

  it "should generate an event if AnimationFinished is received" $
    evts AnimationFinished `shouldBe` Seq.singleton OnTestFinished

  where
    wenv = mockWenv ()
    baseNode = fadeIn_ [autoStart, duration 100, onFinished OnTestFinished] (label "Test")
    node = nodeInit wenv baseNode
    res msg = widgetHandleMessage (node^. L.widget) wenv rootPath msg node
    evts msg = maybe Seq.empty (^. L.events) (res msg)
    reqs msg = maybe Seq.empty (^. L.requests) (res msg)

getSizeReq :: Spec
getSizeReq = describe "getSizeReq" $ do
  it "should return same reqW as child node" $
    tSizeReqW `shouldBe` lSizeReqW

  it "should return same reqH as child node" $
    tSizeReqH `shouldBe` lSizeReqH

  where
    wenv = mockWenvEvtUnit ()
    lblNode = label "Test label"
    (lSizeReqW, lSizeReqH) = nodeGetSizeReq wenv lblNode
    (tSizeReqW, tSizeReqH) = nodeGetSizeReq wenv (fadeIn lblNode)
