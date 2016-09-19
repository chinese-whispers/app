module Msg exposing (Msg(..))

import Router
import Types


type Msg
    = NavigateTo Router.Route
    | LoginFormUsername String
    | LoginFormPassword String
    | Login Types.Credentials
