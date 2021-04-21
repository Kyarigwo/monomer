{-# LANGUAGE ConstraintKinds #-}

module Monomer.Widgets.Singles.TextDropdown (
  textDropdown,
  textDropdown_,
  textDropdownV,
  textDropdownV_,
  textDropdownS,
  textDropdownS_,
  textDropdownSV,
  textDropdownSV_
) where

import Control.Lens (ALens')
import Data.Default
import Data.Text (Text, pack)
import Data.Typeable (Typeable)
import TextShow

import Monomer.Core
import Monomer.Core.Combinators
import Monomer.Widgets.Singles.Label
import Monomer.Widgets.Singles.Dropdown

type TextDropdownItem a = DropdownItem a

textDropdown
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, TextShow a)
  => ALens' s a
  -> t a
  -> WidgetNode s e
textDropdown field items = newNode where
  newNode = textDropdown_ field items showt def

textDropdown_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a)
  => ALens' s a
  -> t a
  -> (a -> Text)
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdown_ field items toText configs = newNode where
  newNode = textDropdownD_ (WidgetLens field) items toText configs

textDropdownV
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, TextShow a)
  => a
  -> (a -> e)
  -> t a
  -> WidgetNode s e
textDropdownV value handler items = newNode where
  newNode = textDropdownV_ value handler items showt def

textDropdownV_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a)
  => a
  -> (a -> e)
  -> t a
  -> (a -> Text)
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdownV_ value handler items toText configs = newNode where
  widgetData = WidgetValue value
  newConfigs = onChange handler : configs
  newNode = textDropdownD_ widgetData items toText newConfigs

textDropdownD_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a)
  => WidgetData s a
  -> t a
  -> (a -> Text)
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdownD_ widgetData items toText configs = newNode where
  makeMain t = label_ (toText t) [resizeFactorW 0.01]
  makeRow t = label_ (toText t) [resizeFactorW 0.01]
  newNode = dropdownD_ widgetData items makeMain makeRow configs

textDropdownS
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, Show a)
  => ALens' s a
  -> t a
  -> WidgetNode s e
textDropdownS field items = newNode where
  newNode = textDropdownS_ field items def

textDropdownS_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, Show a)
  => ALens' s a
  -> t a
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdownS_ field items configs = newNode where
  newNode = textDropdownDS_ (WidgetLens field) items configs

textDropdownSV
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, Show a)
  => a
  -> (a -> e)
  -> t a
  -> WidgetNode s e
textDropdownSV value handler items = newNode where
  newNode = textDropdownSV_ value handler items def

textDropdownSV_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, Show a)
  => a
  -> (a -> e)
  -> t a
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdownSV_ value handler items configs = newNode where
  widgetData = WidgetValue value
  newConfigs = onChange handler : configs
  newNode = textDropdownDS_ widgetData items newConfigs

textDropdownDS_
  :: (Typeable s, WidgetEvent e, Traversable t, TextDropdownItem a, Show a)
  => WidgetData s a
  -> t a
  -> [DropdownCfg s e a]
  -> WidgetNode s e
textDropdownDS_ widgetData items configs = newNode where
  toText = pack . show
  makeMain t = label_ (toText t) [resizeFactorW 0.01]
  makeRow t = label_ (toText t) [resizeFactorW 0.01]
  newNode = dropdownD_ widgetData items makeMain makeRow configs