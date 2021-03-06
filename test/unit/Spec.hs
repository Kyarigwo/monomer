-- {-# OPTIONS_GHC -F -pgmF hspec-discover #-}

import Test.Hspec

import qualified SDL
import qualified SDL.Raw as Raw

import qualified Monomer.Common.CursorIconSpec as CursorIconSpec
import qualified Monomer.Common.PersistSpec as PersistSpec

import qualified Monomer.Widgets.CompositeSpec as CompositeSpec
import qualified Monomer.Widgets.ContainerSpec as ContainerSpec

import qualified Monomer.Widgets.Animation.FadeSpec as AnimationFadeSpec
import qualified Monomer.Widgets.Animation.SlideSpec as AnimationSlideSpec

import qualified Monomer.Widgets.Containers.AlertSpec as AlertSpec
import qualified Monomer.Widgets.Containers.BoxSpec as BoxSpec
import qualified Monomer.Widgets.Containers.ConfirmSpec as ConfirmSpec
import qualified Monomer.Widgets.Containers.DragDropSpec as DragDropSpec
import qualified Monomer.Widgets.Containers.GridSpec as GridSpec
import qualified Monomer.Widgets.Containers.KeystrokeSpec as KeystrokeSpec
import qualified Monomer.Widgets.Containers.ScrollSpec as ScrollSpec
import qualified Monomer.Widgets.Containers.SplitSpec as SplitSpec
import qualified Monomer.Widgets.Containers.StackSpec as StackSpec
import qualified Monomer.Widgets.Containers.ThemeSwitchSpec as ThemeSwitchSpec
import qualified Monomer.Widgets.Containers.TooltipSpec as TooltipSpec
import qualified Monomer.Widgets.Containers.ZStackSpec as ZStackSpec

import qualified Monomer.Widgets.Singles.ButtonSpec as ButtonSpec
import qualified Monomer.Widgets.Singles.CheckboxSpec as CheckboxSpec
import qualified Monomer.Widgets.Singles.DialSpec as DialSpec
import qualified Monomer.Widgets.Singles.DropdownSpec as DropdownSpec
import qualified Monomer.Widgets.Singles.ImageSpec as ImageSpec
import qualified Monomer.Widgets.Singles.LabelSpec as LabelSpec
import qualified Monomer.Widgets.Singles.ListViewSpec as ListViewSpec
import qualified Monomer.Widgets.Singles.NumericFieldSpec as NumericFieldSpec
import qualified Monomer.Widgets.Singles.RadioSpec as RadioSpec
import qualified Monomer.Widgets.Singles.SpacerSpec as SpacerSpec
import qualified Monomer.Widgets.Singles.TextFieldSpec as TextFieldSpec

import qualified Monomer.Widgets.Util.FocusSpec as FocusSpec
import qualified Monomer.Widgets.Util.StyleSpec as StyleSpec
import qualified Monomer.Widgets.Util.TextSpec as TextSpec

main :: IO ()
main = do
  -- Initialize SDL
  SDL.initialize [SDL.InitVideo]
  -- Run tests
  hspec spec
  -- Shutdown SDL
  Raw.quitSubSystem Raw.SDL_INIT_VIDEO
  SDL.quit

spec :: Spec
spec = do
  common
  widgets
  widgetsUtil

common :: Spec
common = describe "Common" $ do
  CursorIconSpec.spec
  PersistSpec.spec

widgets :: Spec
widgets = describe "Widgets" $ do
  CompositeSpec.spec
  ContainerSpec.spec
  animation
  containers
  singles

animation :: Spec
animation = describe "Animation" $ do
  AnimationFadeSpec.spec
  AnimationSlideSpec.spec

containers :: Spec
containers = describe "Containers" $ do
  AlertSpec.spec
  BoxSpec.spec
  ConfirmSpec.spec
  DragDropSpec.spec
  GridSpec.spec
  KeystrokeSpec.spec
  ScrollSpec.spec
  SplitSpec.spec
  StackSpec.spec
  ThemeSwitchSpec.spec
  TooltipSpec.spec
  ZStackSpec.spec

singles :: Spec
singles = describe "Singles" $ do
  ButtonSpec.spec
  CheckboxSpec.spec
  DialSpec.spec
  DropdownSpec.spec
  ImageSpec.spec
  LabelSpec.spec
  ListViewSpec.spec
  NumericFieldSpec.spec
  RadioSpec.spec
  SpacerSpec.spec
  TextFieldSpec.spec

widgetsUtil :: Spec
widgetsUtil = describe "Widgets Util" $ do
  FocusSpec.spec
  StyleSpec.spec
  TextSpec.spec
