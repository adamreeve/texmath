{-
Copyright (C) 2012 John MacFarlane <jgm@berkeley.edu>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

{- | Functions for writing a parsed formula as OMML.
-}

module Text.TeXMath.OMML (toOMML, showExp)
where

import Text.XML.Light
import Text.TeXMath.Types
import Data.Generics (everywhere, mkT)

toOMML :: DisplayType -> [Exp] -> Element
toOMML dt = container . concatMap showExp
            . everywhere (mkT $ handleDownup dt)
    where container = case dt of
                  DisplayBlock  -> \x -> mnode "oMathPara"
                                    [ mnode "oMathParaPr"
                                      $ mnodeA "jc" "center" ()
                                    , mnode "oMath" x ]
                  DisplayInline -> mnode "oMath"

mnode :: Node t => String -> t -> Element
mnode s = node (QName s Nothing (Just "m"))

mnodeA :: Node t => String -> String -> t -> Element
mnodeA s v = add_attr (Attr (QName "val" Nothing (Just "m")) v) . mnode s

str :: [Element] -> String -> Element
str props s = mnode "r" [ mnode "rPr" props
                        , mnode "t" s ]

showBinary :: TextType -> String -> Exp -> Exp -> Element
showBinary format c x y =
  case c of
       "\\frac" -> mnode "f" [ mnode "fPr" $
                                mnodeA "type" "bar" ()
                             , mnode "num" x'
                             , mnode "den" y']
       "\\dfrac" -> showBinary format "\\frac" x y
       "\\tfrac" -> mnode "f" [ mnode "fPr" $
                                 mnodeA "type" "lin" ()
                              , mnode "num" x'
                              , mnode "den" y']
       "\\sqrt"  -> mnode "rad" [ mnode "radPr" $
                                   mnodeA "degHide" "on" ()
                                , mnode "deg" y'
                                , mnode "e" x']
       "\\stackrel" -> mnode "limUpp" [ mnode "e" y'
                                       , mnode "lim" x']
       "\\overset" -> mnode "limUpp" [ mnode "e" y'
                                     , mnode "lim" x' ]
       "\\underset" -> mnode "limLow" [ mnode "e" y'
                                      , mnode "lim" x' ]
       "\\binom"    -> mnode "d" [ mnode "dPr" $
                                     mnodeA "sepChr" "," ()
                                 , mnode "e" $
                                     mnode "f" [ mnode "fPr" $
                                                   mnodeA "type"
                                                     "noBar" ()
                                               , mnode "num" x'
                                               , mnode "den" y' ]] 
       _ -> error $ "Unknown binary operator " ++ c
    where x' = showExp' format x
          y' = showExp' format y

makeArray :: TextType -> [Alignment] -> [ArrayLine] -> Element
makeArray format as rs = mnode "m" $ mProps : map toMr rs
  where mProps = mnode "mPr"
                  [ mnodeA "baseJc" "center" ()
                  , mnodeA "plcHide" "on" ()
                  , mnode "mcs" $ map toMc as' ]
        as'    = take (length rs) $ as ++ cycle [AlignDefault]
        toMr r = mnode "mr" $ map (mnode "e" . concatMap (showExp' format)) r
        toMc a = mnode "mc" $ mnode "mcPr"
                            $ mnodeA "mcJc" (toAlign a) ()
        toAlign AlignLeft    = "left"
        toAlign AlignRight   = "right"
        toAlign AlignCenter  = "center"
        toAlign AlignDefault = "left"

makeText :: TextType -> String -> Element
makeText a s = str attrs s
  where attrs = case a of
                     TextDefault      -> []
                     TextNormal       -> [sty "p"]
                     TextBold         -> [sty "b"]
                     TextItalic       -> [sty "i"]
                     TextMonospace    -> [sty "p", scr "monospace"]
                     TextSansSerif    -> [sty "p", scr "sans-serif"]
                     TextDoubleStruck -> [sty "p", scr "double-struck"]
                     TextScript       -> [sty "p", scr "script"]
                     TextFraktur      -> [sty "p", scr "fraktur"]
                     TextBoldItalic    -> [sty "i"]
                     TextBoldSansSerif -> [sty "b", scr "sans-serif"]
                     TextBoldScript    -> [sty "b", scr "script"]
                     TextBoldFraktur   -> [sty "b", scr "fraktur"]
                     TextSansSerifItalic -> [sty "i", scr "sans-serif"]
                     TextBoldSansSerifItalic -> [sty "bi", scr "sans-serif"]
        sty x = mnodeA "sty" x ()
        scr x = mnodeA "scr" x ()

handleDownup :: DisplayType -> [Exp] -> [Exp]
handleDownup dt (exp' : xs) =
  case exp' of
       EDown x y
         | isNary x  -> EGrouped [constructor x y emptyGroup, next] : rest
         | otherwise -> case dt of
                             DisplayBlock  -> EUnder x y : xs
                             DisplayInline -> ESub x y : xs
       EUp   x y
         | isNary x  -> EGrouped [constructor x emptyGroup y, next] : rest
         | otherwise -> case dt of
                             DisplayBlock  -> EOver x y : xs
                             DisplayInline -> ESuper x y : xs
       EDownup x y z
         | isNary x  -> EGrouped [constructor x y z, next] : rest
         | otherwise -> case dt of
                             DisplayBlock  -> EUnderover x y z : xs
                             DisplayInline -> ESubsup x y z : xs
       ESub x y
         | isNary x  -> EGrouped [ESubsup x y emptyGroup, next] : rest
       ESuper x y
         | isNary x  -> EGrouped [ESubsup x emptyGroup y, next] : rest
       ESubsup x y z
         | isNary x  -> EGrouped [ESubsup x y z, next] : rest
       EOver x y
         | isNary x  -> EGrouped [EUnderover x y emptyGroup, next] : rest
       EUnder x y
         | isNary x  -> EGrouped [EUnderover x emptyGroup y, next] : rest
       EUnderover x y z
         | isNary x  -> EGrouped [EUnderover x y z, next] : rest
       _             -> exp' : next : rest
    where (next, rest) = case xs of
                              (t:ts) -> (t,ts)
                              []     -> (emptyGroup, [])
          emptyGroup = EGrouped []
          constructor = case dt of
                             DisplayBlock  -> EUnderover
                             DisplayInline -> ESubsup
handleDownup _ []            = []

showExp :: Exp -> [Element]
showExp = showExp' TextDefault

showExp' :: TextType -> Exp -> [Element]
showExp' format e =
 case e of
   ENumber x        -> [makeText format x]
   EGrouped [EUnderover (ESymbol Op s) y z, w] -> [makeNary format "undOvr" s y z w]
   EGrouped [ESubsup (ESymbol Op s) y z, w] -> [makeNary format "subSup" s y z w]
   EGrouped xs      -> concatMap (showExp' format) xs
   EDelimited start end xs ->
                       [mnode "d" [ mnode "dPr"
                                    [ mnodeA "begChr" start ()
                                    , mnodeA "endChr" end ()
                                    , mnode "grow" () ]
                                  , mnode "e" $ concatMap (showExp' format) xs
                                  ] ]

   EIdentifier x    -> [makeText format x]
   EMathOperator x  -> [makeText TextNormal x]
   EStretchy x      -> showExp' format x  -- no support for stretchy in OMML
   ESymbol _ x      -> [makeText format x]
   ESpace "0.167em" -> [makeText format "\x2009"]
   ESpace "0.222em" -> [makeText format "\x2005"]
   ESpace "0.278em" -> [makeText format "\x2004"]
   ESpace "0.333em" -> [makeText format "\x2004"]
   ESpace "1em"     -> [makeText format "\x2001"]
   ESpace "2em"     -> [makeText format "\x2001\x2001"]
   ESpace _         -> [] -- this is how the xslt sheet handles all spaces
   EBinary c x y    -> [showBinary format c x y]
   EUnder x (ESymbol Accent [c]) | isBarChar c ->
                       [mnode "bar" [ mnode "barPr" $
                                        mnodeA "pos" "bot" ()
                                    , mnode "e" $ showExp' format x ]]
   EOver x (ESymbol Accent [c]) | isBarChar c ->
                       [mnode "bar" [ mnode "barPr" $
                                        mnodeA "pos" "top" ()
                                    , mnode "e" $ showExp' format x ]]
   EOver x (ESymbol Accent y) ->
                       [mnode "acc" [ mnode "accPr" $
                                        mnodeA "chr" y ()
                                    , mnode "e" $ showExp' format x ]]
   ESub x y         -> [mnode "sSub" [ mnode "e" $ showExp' format x
                                     , mnode "sub" $ showExp' format y]]
   ESuper x y       -> [mnode "sSup" [ mnode "e" $ showExp' format x
                                     , mnode "sup" $ showExp' format y]]
   ESubsup x y z    -> [mnode "sSubSup" [ mnode "e" $ showExp' format x
                                        , mnode "sub" $ showExp' format y
                                        , mnode "sup" $ showExp' format z]]
   EUnder x y       -> [mnode "limLow" [ mnode "e" $ showExp' format x
                                       , mnode "lim" $ showExp' format y]]
   EOver x y        -> [mnode "limUpp" [ mnode "e" $ showExp' format x
                                       , mnode "lim" $ showExp' format y]]
   EUnderover x y z -> showExp' format (EUnder x (EOver y z))
   EUnary "\\sqrt" x  -> [mnode "rad" [ mnode "radPr" $ mnodeA "degHide" "on" ()
                                      , mnode "deg" ()
                                      , mnode "e" $ showExp' format x]]
   EUnary "\\surd" x  -> showExp' format $ EUnary "\\sqrt" x
   EScaled _ x      -> showExp' format x  -- no support for scaler?
   EArray as ls     -> [makeArray format as ls]
   EText s          -> [makeText format s]
   EFormat a x      -> showExp' a x
   x                -> error $ "showExp encountered " ++ show x
   -- note: EUp, EDown, EDownup should be removed by handleDownup

isBarChar :: Char -> Bool
isBarChar c = c == '\x203E' || c == '\x00AF'

isNary :: Exp -> Bool
isNary (ESymbol Op _) = True
isNary _ = False

makeNary :: TextType -> String -> String -> Exp -> Exp -> Exp -> Element
makeNary format t s y z w =
  mnode "nary" [ mnode "naryPr"
                 [ mnodeA "chr" s ()
                 , mnodeA "limLoc" t ()
                 , mnodeA "supHide"
                    (if y == EGrouped [] then "on" else "off") ()
                 , mnodeA "supHide"
                    (if y == EGrouped [] then "on" else "off") ()
                 ]
               , mnode "e" $ showExp' format w
               , mnode "sub" $ showExp' format y
               , mnode "sup" $ showExp' format z ]

