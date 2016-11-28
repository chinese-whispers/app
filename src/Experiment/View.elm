module Experiment.View exposing (view)

import Clock
import Experiment.Instructions as Instructions
import Experiment.Model as ExpModel
import Experiment.Msg exposing (Msg(..))
import Feedback
import Form
import Helpers
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Intro
import Lifecycle
import Model exposing (Model)
import Msg as AppMsg
import Router
import Styles exposing (class, classList, id)
import Types


view : (Msg -> AppMsg.Msg) -> Model -> List (Html.Html AppMsg.Msg)
view lift model =
    case model.auth of
        Types.Authenticated { user, meta } ->
            [ Html.header [] (header lift user.profile meta model.experiment)
            , Html.main_ [] [ (body lift user.profile meta model.experiment) ]
            ]

        Types.Authenticating ->
            [ Helpers.loading ]

        Types.Anonymous ->
            [ Helpers.notAuthed ]


header :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> ExpModel.Model
    -> List (Html.Html AppMsg.Msg)
header lift profile meta model =
    let
        title =
            case Lifecycle.state meta profile of
                Lifecycle.Training _ ->
                    "Experiment — Training"

                Lifecycle.Experiment _ ->
                    "Experiment"

                Lifecycle.Done ->
                    "Experiment — Done"

        instructionsState =
            if Lifecycle.stateIsCompletable meta profile then
                ExpModel.instructionsState model
            else
                Intro.hide
    in
        [ Html.nav [] [ Helpers.navButton Router.Home "Back" ]
        , Intro.node
            (Instructions.viewConfig lift)
            instructionsState
            Instructions.Title
            Html.h1
            []
            [ Html.text title ]
        ]


body :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> ExpModel.Model
    -> Html.Html AppMsg.Msg
body lift profile meta model =
    let
        expView =
            case model.state of
                ExpModel.JustFinished ->
                    Html.div [ class [ Styles.Narrow ] ]
                        [ Html.div [] [ Html.text "TODO: just finished previous run" ] ]

                ExpModel.Instructions introState ->
                    Html.div [ class [ Styles.Normal ] ]
                        [ Html.div [] (instructions lift model.loadingNext introState) ]

                ExpModel.Trial trialModel ->
                    Html.div [ class [ Styles.Narrow ] ]
                        [ Html.div [] (trial lift model.loadingNext trialModel) ]

        finishProfileView =
            Html.div [ class [ Styles.Narrow ] ]
                [ Html.div [] [ Html.text "TODO: go finish your profile" ] ]

        uncompletableView =
            Html.div [ class [ Styles.Narrow ] ]
                [ Html.div [] [ Html.text "TODO: state uncompletable error" ] ]
    in
        case Lifecycle.state meta profile of
            Lifecycle.Experiment tests ->
                if List.length tests == 0 then
                    if Lifecycle.stateIsCompletable meta profile then
                        expView
                    else
                        uncompletableView
                else
                    finishProfileView

            Lifecycle.Training _ ->
                if Lifecycle.stateIsCompletable meta profile then
                    expView
                else
                    uncompletableView

            Lifecycle.Done ->
                Html.div [ class [ Styles.Narrow ] ]
                    [ Html.div [] [ Html.text "TODO: exp done" ] ]


instructions :
    (Msg -> AppMsg.Msg)
    -> Bool
    -> Intro.State Instructions.Node
    -> List (Html.Html AppMsg.Msg)
instructions lift loading state =
    [ Intro.node
        (Instructions.viewConfig lift)
        state
        Instructions.A
        Html.p
        []
        [ Html.text "First stuff" ]
    , Intro.node
        (Instructions.viewConfig lift)
        state
        Instructions.B
        Html.p
        []
        [ Html.text "Second stuff" ]
    , Helpers.evButton
        [ Attributes.disabled loading ]
        (lift InstructionsStart)
        "Replay instructions"
    , Helpers.evButton
        [ Attributes.disabled loading ]
        (lift LoadTrial)
        "Start"
    , Intro.overlay state
    ]


trial : (Msg -> AppMsg.Msg) -> Bool -> ExpModel.TrialModel -> List (Html.Html AppMsg.Msg)
trial lift loading trialModel =
    case trialModel.state of
        ExpModel.Reading ->
            [ Html.text "Read"
            , Html.p [] [ Html.text trialModel.current.text ]
            , Clock.view trialModel.clock
            ]

        ExpModel.Tasking ->
            [ Html.text "Tasking"
            , Clock.view trialModel.clock
            ]

        ExpModel.Writing form ->
            write lift loading trialModel form

        ExpModel.Timeout ->
            [ Html.text "TODO: timeout"
            , Helpers.evButton [ Attributes.disabled loading ] (lift LoadTrial) "Next"
            ]

        ExpModel.Pause ->
            [ Html.text "TODO: pause"
            , Helpers.evButton [ Attributes.disabled loading ] (lift LoadTrial) "Next"
            ]


write :
    (Msg -> AppMsg.Msg)
    -> Bool
    -> ExpModel.TrialModel
    -> Form.Model String
    -> List (Html.Html AppMsg.Msg)
write lift loading trialModel { input, feedback, status } =
    [ Html.text "Write"
    , Html.form [ Events.onSubmit (lift <| WriteSubmit input) ]
        [ Html.div []
            [ Html.label [ Attributes.for "inputText" ] [ Html.text "Write:" ]
            , Html.textarea
                [ Attributes.id "inputText"
                , Attributes.autofocus True
                , Attributes.value input
                , Attributes.disabled (loading || (status /= Form.Entering))
                , Events.onInput (lift << WriteInput)
                ]
                []
            , Html.span [] [ Html.text (Feedback.getError "global" feedback) ]
            ]
        , Html.button
            [ Attributes.type_ "submit"
            , Attributes.disabled (loading || (status /= Form.Entering))
            ]
            [ Html.text "Send" ]
        ]
    , Clock.view trialModel.clock
    ]
