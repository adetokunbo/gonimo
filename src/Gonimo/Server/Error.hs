{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
module Gonimo.Server.Error where


import           Control.Exception             (Exception, SomeException,
                                                toException)
import           Control.Monad                 (unless, MonadPlus, mzero, (<=<))
import           Control.Monad.Trans.Maybe     (runMaybeT, MaybeT)
import           Control.Monad.Freer
import           Control.Monad.Freer.Exception
import           Data.Aeson
import           Data.Typeable                 (Typeable)
import           GHC.Generics
import           Gonimo.Server.Db.Entities      (FamilyId, DeviceId)
import           Servant.Server
import           Control.Monad.Trans.Class            (lift)

-- Define an error type, so handling errors is easier at the client side.
data ServerError = InvalidAuthToken
                 | InvitationAlreadyClaimed -- ^ Invitation was already claimed by someone else.
                 | AlreadyFamilyMember -- ^ If a client tries to become a member of a family he is already a member of.
                 | NoSuchDevice DeviceId -- ^ The device could not be found in the database.
                 | NoSuchFamily FamilyId
                 | FamilyNotOnline FamilyId
                 | NoSuchInvitation
                 | SocketBusy
                 | ChannelBusy
                 | NoSuchSocket
                 | NoSuchChannel
                 | Forbidden
                 | NotFound
                 | TransactionTimeout
                 | SessionInvalid -- There exists a session for this device, but it does not match
                 | NoActiveSession -- There is no sessino for this device.
                 | InternalServerError
  deriving (Generic)

-- | Errors that can be converted to a ServerError.
class ToServerError e where
  toServerError :: MonadPlus m => e -> m ServerError

instance ToServerError ServerError where
  toServerError = return

fromMaybeErr :: Member (Exc SomeException) r => ServerError -> Maybe a -> Eff r a
fromMaybeErr err ma = case ma of
  Nothing -> throwServer err
  Just a  -> return a

throwLeft :: Member (Exc SomeException) r => Either ServerError a -> Eff r a
throwLeft = either throwServer return

-- | Throw left if actually a ServerError, otherwise return Nothing
mayThrowLeft :: (Member (Exc SomeException) r, ToServerError e) => Either e a -> MaybeT (Eff r) a
mayThrowLeft = either (lift . throwServer <=< toServerError) return

throwServer :: Member (Exc SomeException) r => ServerError -> Eff r a
throwServer = throwServant . makeServantErr

guardWith :: Member (Exc SomeException) r => ServerError -> Bool -> Eff r ()
guardWith exc cond = unless cond $ throwServer exc

guardWithM :: Member (Exc SomeException) r => ServerError -> Eff r Bool -> Eff r ()
guardWithM exc mCond = guardWith exc =<< mCond

throwServant :: Member (Exc SomeException) r => ServantErr -> Eff r a
throwServant = throwException . ServantException

throwException :: (Member (Exc SomeException) r, Exception e) => e -> Eff r a
throwException = throwError . toException

makeServantErr :: ServerError -> ServantErr
makeServantErr err = (getServantErr err) { errBody = encode err }


-- | Internal
getServantErr :: ServerError -> ServantErr
getServantErr InvalidAuthToken = err403
getServantErr InvitationAlreadyClaimed = err403
getServantErr AlreadyFamilyMember = err409
getServantErr (NoSuchFamily _) = err404
getServantErr (FamilyNotOnline _) = err404
getServantErr NoSuchInvitation = err404
getServantErr SocketBusy = err503
getServantErr ChannelBusy = err503
getServantErr NoSuchSocket = err404
getServantErr NoSuchChannel = err404
getServantErr NotFound = err404
getServantErr Forbidden = err403
getServantErr TransactionTimeout = err500
getServantErr SessionInvalid = err409
getServantErr NoActiveSession = err404
getServantErr InternalServerError = err500

instance ToJSON ServerError where
    toJSON = genericToJSON defaultOptions


-- TODO: No longer needed, my PR making ServantErr an instance of Exception got already merged.
newtype ServantException = ServantException {
  unwrapServantErr :: ServantErr
  } deriving (Show, Typeable)

instance Exception ServantException
