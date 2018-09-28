# Twilio Video ReplayKit Example

The project demonstrates how to use Twilio's Programmable Video SDK with `ReplayKit.framework` in a Broadcast Extension.

### Setup

See the master [README](https://github.com/twilio/video-quickstart-swift/blob/master/README.md) for instructions on how to generate access tokens and connect to a Room.

This example requires Xcode 10.0 and the iOS 12.0 SDK, as well as a device running iOS 10.0 or above.

### Running

Once you have setup your access token, install and run the example. You will be presented with the following screen:

< TODO, update image >

<kbd><img width="400px" src="../images/quickstart/audio-sink-launched.jpg"/></kbd>

### Known Issues

1. Memory usage in a ReplayKit Broadcast Extension is limited to 50 MB (as of iOS 12.0). There are cases where Twilio Video can use more than this amount, especially when capturing larger 2x and 3x retina screens. This example uses downscaling to reduce the amount of memory needed by our process.