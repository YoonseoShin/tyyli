# TestFlight Review Information

Use the text below in App Store Connect before submitting the external TestFlight build.

## Beta App Description

Tyyli is an AI personal stylist that turns clothing photos into a private, on-device digital closet. Users can analyze clothing, build outfit recommendations from items they already own, and ask the AI stylist what to wear or buy based on their preferences, weather, and plans.

## What to Test

Please complete onboarding, add clothing from the camera or photo library, run AI clothing analysis, and generate an outfit after saving either a top and bottom or a dress. Try swapping an item, saving the outfit to History, and asking the AI stylist a clothing question. Please report unclear screens, incorrect clothing details, slow AI responses, or crashes.

## Review Notes

No account or sign-in is required.

Suggested review path:

1. Complete the style onboarding.
2. Open Closet and add a clothing photo from the camera or photo library.
3. Use AI analysis to generate the clothing type, colors, mood, seasons, occasions, and warmth.
4. Add enough clothing for an outfit: either a top and bottom or a dress.
5. On Home, generate AI outfit picks and open a pick to see its explanation.
6. Open Stylist and ask a clothing or outfit question.

The app stores closet photos, clothing metadata, profile data, outfit picks, and history locally on the device. AI features send only the request-specific inputs to Tyyli's hosted Jac API, which uses Anthropic Claude. Visual product search also uses SerpApi. Weather uses Open-Meteo. The app starts a harmless health request when opened so the free hosted API can wake before the first AI action.

Production AI calls are protected with Apple App Attest and are intended to be tested from the TestFlight build on a physical supported iPhone. If an AI style-identity request is temporarily unavailable during onboarding, the app creates a local fallback identity so the reviewer can continue.

## App Review Contact

- First name: Shea
- Last name: Shin
- Email: yoonseos@umich.edu
- Phone: **Add a phone number in App Store Connect**

## Privacy Policy URL

https://github.com/YoonseoShin/tyyli/blob/release/PRIVACY.md
