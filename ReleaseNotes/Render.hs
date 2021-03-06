module ReleaseNotes.Render where
    
import Text.Hastache 
import Text.Hastache.Context 
import ReleaseNotes.Data
import Data.Text
import Data.ByteString.Lazy.Internal
import qualified Data.Text.Lazy.Encoding as TL
import qualified Data.Text.Lazy as TL

render :: String -> [Group] -> IO Text
render template grps = 
    fmap (TL.toStrict . TL.decodeLatin1)  $ 
    -- fmap TL.toStrict $ 
    hastacheFile defaultConfig template (mkGenericContext $ Groups grps)