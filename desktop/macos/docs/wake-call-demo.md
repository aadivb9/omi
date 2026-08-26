# Wake Call prototype

Wake Call is a two-minute desktop prototype in **Settings → Notifications & Privacy**. It demonstrates a wake-up safety net: Omi rings the Mac, gives the person a chance to acknowledge, and then shows a phone-handoff escalation.

The desktop chat can also set a real local Mac alarm. Ask: **“Set an alarm for 30 seconds from now.”** Omi now uses the `set_alarm` tool instead of offering to create a task. Omi beeps while open and schedules a macOS notification for background delivery. High-priority tasks due today automatically receive an alarm five minutes before their due time.

## Demo script

1. Open **Settings → Notifications & Privacy** and scroll to **Wake Call**.
2. Set a wake time, then choose **Start 12-second demo**.
3. Let the Mac alarm fire. The card changes to **Wake up** and plays the system beep.
4. Let it run for another eight seconds to show **Phone handoff started**, or choose **I'm awake** to stop it.

The card deliberately labels phone handoff as demo-only: it does not place a phone call. Omi already has verified-number and Twilio call infrastructure, but a production Wake Call needs a server-owned scheduler, verified-number selection, consent, retries, and acknowledgement handling before it may make outbound calls.
