module Home.View exposing (view, instructions)

import Explore.Router
import Helpers
import Home.Model as HomeModel
import Home.Msg exposing (Msg(..))
import Html
import Intro
import Lifecycle
import List.Nonempty as Nonempty
import List.Nonempty exposing (Nonempty)
import Model exposing (Model)
import Msg as AppMsg
import Router
import Strings
import Styles exposing (class, classList, id)
import Types
import View.Common as Common


-- INSTRUCTIONS


instructions : Nonempty ( HomeModel.Node, ( Intro.Position, Html.Html AppMsg.Msg ) )
instructions =
    Nonempty.Nonempty
        ( HomeModel.Greeting
        , ( Intro.Bottom, Html.p [] [ Html.text Strings.homeInstructionsGreeting ] )
        )
        [ ( HomeModel.Profile
          , ( Intro.Left
            , Html.div []
                [ Html.p [] [ Html.text Strings.homeInstructionsProfileTests ]
                , Html.p [] [ Html.text Strings.homeInstructionsProfileTestsWhenever ]
                ]
            )
          )
        , ( HomeModel.Body
          , ( Intro.Bottom, Html.p [] [ Html.text Strings.homeInstructionsGetGoing ] )
          )
        ]


instructionsConfig : (Msg -> AppMsg.Msg) -> Intro.ViewConfig HomeModel.Node AppMsg.Msg
instructionsConfig lift =
    Intro.viewConfig
        { liftMsg = lift << InstructionsMsg
        , tooltip = (\i -> Tuple.second (Nonempty.get i instructions))
        }



-- VIEW


view : (Msg -> AppMsg.Msg) -> Model -> List (Html.Html AppMsg.Msg)
view lift model =
    [ Html.header [] (header lift model)
    , Html.main_ []
        [ Html.div [ class [ Styles.SuperNarrow ] ]
            [ Html.div [] [ greeting lift model, controls lift model ] ]
        ]
    , Html.footer [] (footer lift model)
    , Intro.overlay model.home
    ]


header : (Msg -> AppMsg.Msg) -> Model -> List (Html.Html AppMsg.Msg)
header lift model =
    case model.auth of
        Types.Anonymous ->
            []

        Types.Authenticating ->
            []

        Types.Authenticated { user } ->
            let
                adminControls =
                    if user.isStaff then
                        [ Helpers.navIcon [ class [ Styles.Big ] ]
                            (Router.Explore <| Router.Trees <| Explore.Router.initialParams)
                            "globe"
                        , Helpers.navIcon [ class [ Styles.Big ] ] Router.Admin "user-md"
                        ]
                    else
                        []
            in
                [ Intro.node
                    (instructionsConfig lift)
                    model.home
                    HomeModel.Profile
                    Html.div
                    [ class [ Styles.Meta, Styles.FlexCenter ] ]
                    ([ Html.span []
                        [ Html.text "Howdy, "
                        , Html.strong [] [ Html.text user.username ]
                        ]
                     , Helpers.avatar user (Router.Profile Router.Dashboard)
                     ]
                        ++ adminControls
                    )
                ]


greeting : (Msg -> AppMsg.Msg) -> Model -> Html.Html AppMsg.Msg
greeting lift model =
    Intro.node
        (instructionsConfig lift)
        model.home
        HomeModel.Greeting
        Html.div
        [ id Styles.Greeting ]
        [ Html.h1 [] [ Html.text "Gistr" ]
        , Html.p [] Strings.homeSubtitle
        ]


controls : (Msg -> AppMsg.Msg) -> Model -> Html.Html AppMsg.Msg
controls lift model =
    let
        introBlock buttons =
            Html.div []
                [ Intro.node
                    (instructionsConfig lift)
                    model.home
                    HomeModel.Body
                    Html.div
                    []
                    [ Html.div [] Strings.homeQuestions
                    , buttons
                    ]
                ]
    in
        case model.auth of
            Types.Anonymous ->
                introBlock <|
                    Html.div []
                        [ Html.p [] <|
                            (Helpers.navButton
                                [ class [ Styles.Btn, Styles.BtnPrimary ] ]
                                (Router.Register Nothing)
                                "Pass the experiment"
                            )
                                :: Strings.homeGetPaid
                        , Html.p []
                            [ Helpers.navButton
                                [ class [ Styles.Btn ] ]
                                (Router.Login Nothing)
                                "Sign in"
                            , Html.text Strings.homeIfStarted
                            ]
                        ]

            Types.Authenticating ->
                Helpers.loading Styles.Big

            Types.Authenticated { user, meta } ->
                case Lifecycle.state meta user.profile of
                    Lifecycle.Done ->
                        Html.div []
                            ((Html.h3 [] [ Html.text Strings.expDone ])
                                :: (Common.prolificCompletion user.profile)
                                ++ Strings.expDoneReadAbout
                            )

                    _ ->
                        introBlock <|
                            Html.div []
                                [ Helpers.navButton
                                    [ class [ Styles.Btn, Styles.BtnPrimary ] ]
                                    Router.Experiment
                                    "Pass the experiment"
                                ]


footer : (Msg -> AppMsg.Msg) -> Model -> List (Html.Html AppMsg.Msg)
footer lift model =
    let
        devs =
            Helpers.hrefIcon
                [ class [ Styles.Small ], Helpers.tooltip "Email the developers" ]
                "mailto:sl@mehho.net"
                "envelope"

        about =
            Helpers.navIcon
                [ class [ Styles.Small ], Helpers.tooltip "About Gistr" ]
                Router.About
                "info-circle"

        twitter =
            Helpers.hrefIcon
                [ class [ Styles.Small ], Helpers.tooltip "Twitter" ]
                "https://twitter.com/gistrexp"
                "twitter"

        github =
            Helpers.hrefIcon
                [ class [ Styles.Small ], Helpers.tooltip "GitHub" ]
                "https://github.com/interpretation-experiment/gistr-app"
                "github"

        intro =
            Helpers.evIconButton
                [ class [ Styles.Small, Styles.NavIcon ], Helpers.tooltip "Play intro" ]
                (lift InstructionsStart)
                "question-circle"

        icons =
            case model.auth of
                Types.Anonymous ->
                    [ devs, about ]

                Types.Authenticating ->
                    [ devs, about ]

                Types.Authenticated { user, meta } ->
                    if user.isStaff then
                        [ devs, about, twitter, github, intro ]
                    else
                        case Lifecycle.state meta user.profile of
                            Lifecycle.Training _ ->
                                [ devs, about, intro ]

                            Lifecycle.Experiment _ ->
                                [ devs, about, intro ]

                            Lifecycle.Done ->
                                [ devs, about, twitter, github ]
    in
        [ Html.div [] icons ]
