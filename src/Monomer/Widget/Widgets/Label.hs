{-# LANGUAGE RecordWildCards #-}

module Monomer.Widget.Widgets.Label (label) where

import Control.Monad

import qualified Data.Text as T

import Monomer.Common.Style
import Monomer.Common.Tree
import Monomer.Common.Types
import Monomer.Graphics.Drawing
import Monomer.Widget.BaseWidget
import Monomer.Widget.Types
import Monomer.Widget.Util

label :: (Monad m) => T.Text -> WidgetInstance s e m
label caption = defaultWidgetInstance "label" (makeLabel caption)

makeLabel :: (Monad m) => T.Text -> Widget s e m
makeLabel caption = createWidget {
    _widgetPreferredSize = preferredSize,
    _widgetRender = render
  }
  where
    preferredSize renderer app widgetInstance = do
      let Style{..} = _instanceStyle widgetInstance

      size <- calcTextBounds renderer _textStyle (if caption == "" then " " else caption)
      return . singleton $ SizeReq size FlexibleSize FlexibleSize

    render renderer ts app WidgetInstance{..} =
      do
        drawBgRect renderer _instanceRenderArea _instanceStyle
        drawText_ renderer _instanceRenderArea (_textStyle _instanceStyle) caption