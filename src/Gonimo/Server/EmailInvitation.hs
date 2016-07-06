{-# LANGUAGE QuasiQuotes #-}
module Gonimo.Server.EmailInvitation (
  makeInvitationEmail) where

import           Data.Text                (Text)
import           NeatInterpolation
import           Network.Mail.Mime        (Address (..), Mail, simpleMail')
import           Web.HttpApiData
import qualified Data.Text.Lazy           as TL

import           Gonimo.Server.DbEntities hiding (familyName)
import           Gonimo.Server.Types
import           Gonimo.WebAPI.Types



invitationText :: Invitation -> FamilyName -> Text
invitationText _inv _n =
  [text|
    Dear User of gonimo.com!

    You got invited to join gonimo family "$_n"!
    Just click on the link below and you are all set for the best baby monitoring on the planet!

    https://gonimo.com/index.html?acceptInvitation=$secret
  |]
  where
    secret = toUrlPiece $ invitationSecret _inv


makeInvitationEmail :: Invitation -> EmailAddress -> FamilyName -> Mail
makeInvitationEmail inv addr name = simpleMail' receiver sender "You got invited to a family on gonimo.com" (TL.fromStrict textContent)
  where
    textContent = invitationText inv name
    receiver = Address Nothing addr
    sender = Address Nothing "noreply@gonimo.com"
