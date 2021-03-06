module Cmds exposing (autofocus, cmdsForModel)

import Api
import Dom
import Experiment.Msg as ExperimentMsg
import Explore.Cmds
import Home.Msg as HomeMsg
import Lifecycle
import Model exposing (Model)
import Msg exposing (Msg)
import Profile.Msg as ProfileMsg
import Router
import Styles
import Task
import Types


autofocus : Cmd Msg
autofocus =
    let
        focusLog result =
            let
                log =
                    case result of
                        Err _ ->
                            "no autofocus found"

                        Ok _ ->
                            "autofocused"
            in
                Msg.Log log
    in
        toString Styles.InputAutofocus
            |> Dom.focus
            |> Task.attempt focusLog


cmdsForModel : Model -> List (Cmd Msg)
cmdsForModel model =
    autofocus :: (nonFocusCmds model)


nonFocusCmds : Model -> List (Cmd Msg)
nonFocusCmds model =
    case model.route of
        Router.Profile (Router.Confirm key) ->
            authenticatedOrIgnore model <|
                \auth ->
                    case model.emailConfirmation of
                        Model.SendingConfirmation ->
                            [ Task.attempt
                                (Msg.ProfileMsg << ProfileMsg.ConfirmEmailResult)
                                (Api.confirmEmail auth key)
                            ]

                        _ ->
                            []

        Router.Profile (Router.Dashboard) ->
            authenticatedOrIgnore model <|
                \auth ->
                    case auth.user.profile.wordSpanId of
                        Nothing ->
                            []

                        Just id ->
                            [ Task.attempt Msg.WordSpanResult (Api.getWordSpan auth id) ]

        Router.Experiment ->
            authenticatedOrIgnore model <|
                \auth ->
                    if
                        (not auth.user.profile.introducedExpPlay
                            && Lifecycle.stateIsCompletable auth.meta auth.user.profile
                        )
                    then
                        [ Task.perform
                            (always <| Msg.ExperimentMsg ExperimentMsg.InstructionsStart)
                            (Task.succeed ())
                        ]
                    else
                        []

        Router.Home ->
            authenticatedOrIgnore model <|
                \auth ->
                    if
                        (not auth.user.profile.introducedExpHome
                            && (Lifecycle.state auth.meta auth.user.profile /= Lifecycle.Done)
                        )
                    then
                        [ Task.perform
                            (always <| Msg.HomeMsg HomeMsg.InstructionsStart)
                            (Task.succeed ())
                        ]
                    else
                        []

        Router.Explore exploreRoute ->
            authenticatedOrIgnore model <|
                \auth ->
                    Explore.Cmds.cmdsForModel Msg.ExploreMsg auth model.explore exploreRoute

        _ ->
            []



-- CMD HELPERS


authenticatedOrIgnore :
    Model
    -> (Types.Auth -> List (Cmd Msg))
    -> List (Cmd Msg)
authenticatedOrIgnore model authFunc =
    case model.auth of
        Types.Authenticated auth ->
            authFunc auth

        _ ->
            []
