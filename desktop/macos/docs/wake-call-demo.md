# Wake Call

Wake Call is an opt-in alarm escalation in **Settings → Notifications & Privacy**. Omi rings the Mac, gives the person eight seconds to acknowledge, and then either calls the account owner's verified primary phone number or starts a local FaceTime Audio handoff. It does not need a separate Omi phone app.

The desktop chat can also set a real local Mac alarm. Ask: **“Set an alarm for 30 seconds from now.”** Omi uses the `set_alarm` tool instead of creating a task. It rings while open and schedules a macOS notification for background delivery. High-priority tasks due today automatically receive a Mac alarm five minutes before their due time.

## Demo script

1. Open **Settings → Notifications & Privacy** and scroll to **Wake Call**.
2. Add your phone number in E.164 format and choose **Verify phone**. Answer Omi's verification call and enter its code, then choose **Check verification**.
3. Enable **Call my verified phone after 8 seconds**, then choose **Start 12-second demo**.
4. Let the Mac alarm fire. The card changes to **Wake up** and rings the Mac.
5. Let it run for another eight seconds: Omi calls the verified number. Choose **I'm awake** before escalation to stop the handoff.

### Use it immediately with FaceTime

If the Omi phone-call plan is unavailable, enable **Use FaceTime Audio for my personal wake call**, enter the Apple ID email (or phone number) that receives FaceTime on your phone, and use **Test FaceTime handoff**. This opens FaceTime Audio from the Mac; it uses the Mac's signed-in Apple account and does not consume an Omi phone-call allowance.

## Server configuration

Set `TWILIO_WAKE_CALLER_ID` to a Twilio number owned by Omi. This is the caller ID used for wake calls. The backend refuses to place a wake call without it, rather than calling a person from their own number. For a local backend, add it to `backend/.env`; deployed environments receive it through the standard backend config map.
