import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class StepFieldView extends WatchUi.DataField {

    hidden var mStepName as String = "";
    hidden var mHrRange as String = "";
    hidden var mRemaining as String = "";
    hidden var mColor as Number = Graphics.COLOR_WHITE;

    // Step tracking for countdown
    hidden var mStepStartTimer as Number = 0;    // timerTime (ms) at step start
    hidden var mStepStartDist as Float = 0.0f;   // elapsedDistance (m) at step start
    hidden var mStepDuration as Number = 0;      // step duration in seconds (time-based)
    hidden var mStepDistance as Float = 0.0f;     // step distance in meters (distance-based)
    hidden var mIsTimeBased as Boolean = true;
    hidden var mHasStep as Boolean = false;

    function initialize() {
        DataField.initialize();
    }

    function onTimerStart() as Void {
        captureStepStart();
    }

    function onWorkoutStepComplete() as Void {
        captureStepStart();
    }

    hidden function captureStepStart() as Void {
        var info = Activity.getActivityInfo();
        if (info != null) {
            mStepStartTimer = (info.timerTime != null) ? info.timerTime as Number : 0;
            mStepStartDist = (info.elapsedDistance != null) ? info.elapsedDistance as Float : 0.0f;
        }

        var stepInfo = Activity.getCurrentWorkoutStep();
        if (stepInfo == null) {
            mHasStep = false;
            return;
        }
        mHasStep = true;

        var step = stepInfo.step;
        if (step has :durationType && step has :durationValue && step.durationValue != null) {
            var dt = step.durationType;
            var dv = step.durationValue as Number;
            if (dt == 0) {
                // Time-based: value in seconds
                mIsTimeBased = true;
                mStepDuration = dv;
                mStepDistance = 0.0f;
            } else if (dt == 1) {
                // Distance-based: value in meters
                mIsTimeBased = false;
                mStepDistance = dv.toFloat();
                mStepDuration = 0;
            }
        }
    }

    function compute(info as Activity.Info) as Void {
        var stepInfo = Activity.getCurrentWorkoutStep();
        if (stepInfo == null) {
            mHasStep = false;
            mStepName = "";
            mHrRange = "";
            mRemaining = "";
            return;
        }
        mHasStep = true;

        // Step name
        if (stepInfo has :name && stepInfo.name != null && stepInfo.name.length() > 0) {
            mStepName = stepInfo.name.toUpper();
        } else {
            mStepName = intensityLabel(stepInfo.intensity);
        }

        // HR range
        var step = stepInfo.step;
        if (step has :targetType && step has :targetValueLow && step has :targetValueHigh) {
            if (step.targetType == 1) {
                var lo = step.targetValueLow;
                var hi = step.targetValueHigh;
                if (lo != null && hi != null) {
                    lo -= 100;
                    hi -= 100;
                    if (lo > 0 && hi > 0) {
                        mHrRange = lo + "-" + hi;
                    } else {
                        mHrRange = "";
                    }
                } else {
                    mHrRange = "";
                }
            } else {
                mHrRange = "";
            }
        } else {
            mHrRange = "";
        }

        // Remaining countdown
        if (mIsTimeBased && mStepDuration > 0 && info.timerTime != null) {
            var elapsed = ((info.timerTime as Number) - mStepStartTimer) / 1000;
            var remaining = mStepDuration - elapsed;
            if (remaining < 0) { remaining = 0; }
            mRemaining = formatCountdown(remaining);
        } else if (!mIsTimeBased && mStepDistance > 0.0f && info.elapsedDistance != null) {
            var remaining = mStepDistance - ((info.elapsedDistance as Float) - mStepStartDist);
            if (remaining < 0.0f) { remaining = 0.0f; }
            mRemaining = formatDistance(remaining);
        } else {
            mRemaining = "";
        }

        // Color
        mColor = intensityColor(stepInfo.intensity);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (!mHasStep) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
                Graphics.FONT_SMALL, "No step",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();

        // Pick fonts based on field height — must be readable at a glance
        var nameFont = Graphics.FONT_MEDIUM;
        var detailFont = Graphics.FONT_SMALL;
        if (h >= 120) {
            nameFont = Graphics.FONT_LARGE;
            detailFont = Graphics.FONT_MEDIUM;
        } else if (h < 60) {
            nameFont = Graphics.FONT_SMALL;
            detailFont = Graphics.FONT_XTINY;
        }

        var nameH = dc.getFontHeight(nameFont);
        var detailH = dc.getFontHeight(detailFont);
        var gap = 2;
        var lines = 1;
        if (mHrRange.length() > 0) { lines++; }
        if (mRemaining.length() > 0) { lines++; }
        var totalH = nameH + (lines - 1) * (detailH + gap);
        var y = (h - totalH) / 2;
        var cx = w / 2;

        // Step name — intensity colored
        dc.setColor(mColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, nameFont, mStepName, Graphics.TEXT_JUSTIFY_CENTER);
        y += nameH + gap;

        // HR range
        if (mHrRange.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mHrRange, Graphics.TEXT_JUSTIFY_CENTER);
            y += detailH + gap;
        }

        // Remaining
        if (mRemaining.length() > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mRemaining, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // --- Helpers ---

    hidden function formatCountdown(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m + ":" + s.format("%02d");
    }

    hidden function formatDistance(meters as Float) as String {
        if (meters >= 1000.0f) {
            return (meters / 1000.0f).format("%.1f") + "km";
        }
        return meters.toNumber() + "m";
    }

    hidden function intensityColor(intensity as Activity.WorkoutIntensity) as Number {
        if (intensity == Activity.WORKOUT_INTENSITY_WARMUP ||
            intensity == Activity.WORKOUT_INTENSITY_COOLDOWN) {
            return 0x55FF55;
        }
        if (intensity == Activity.WORKOUT_INTENSITY_RECOVERY ||
            intensity == Activity.WORKOUT_INTENSITY_REST) {
            return 0x00CCFF;
        }
        return 0xFF6666;
    }

    hidden function intensityLabel(intensity as Activity.WorkoutIntensity) as String {
        if (intensity == Activity.WORKOUT_INTENSITY_WARMUP) { return "WARMUP"; }
        if (intensity == Activity.WORKOUT_INTENSITY_COOLDOWN) { return "COOLDOWN"; }
        if (intensity == Activity.WORKOUT_INTENSITY_RECOVERY) { return "RECOVERY"; }
        if (intensity == Activity.WORKOUT_INTENSITY_REST) { return "REST"; }
        return "RUN";
    }
}
