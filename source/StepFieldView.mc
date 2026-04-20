import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

class StepFieldView extends WatchUi.DataField {

    hidden var mStepName as String = "";
    hidden var mTargetRange as String = "";
    hidden var mRemaining as String = "";
    hidden var mColor as Number = 0xFFFFFF;

    hidden var mStepStartTimer as Number = 0;
    hidden var mStepStartDist as Float = 0.0f;
    hidden var mStepDuration as Number = 0;
    hidden var mStepDistance as Float = 0.0f;
    hidden var mIsTimeBased as Boolean = true;
    hidden var mHasStep as Boolean = false;

    function initialize() {
        DataField.initialize();
    }

    function onTimerStart() as Void {
        captureStepStart();
    }

    function onTimerReset() as Void {
        mHasStep = false;
    }

    function onWorkoutStepComplete() as Void {
        captureStepStart();
    }

    hidden function toNum(val) as Number {
        if (val instanceof Number) { return val; }
        if (val instanceof Float) { return val.toNumber(); }
        if (val instanceof Long) { return val.toNumber(); }
        if (val instanceof Double) { return val.toNumber(); }
        if (val instanceof String) { return val.toNumber(); }
        return 0;
    }

    hidden function toFlt(val) as Float {
        if (val instanceof Float) { return val; }
        if (val instanceof Number) { return val.toFloat(); }
        if (val instanceof Long) { return val.toFloat(); }
        if (val instanceof Double) { return val.toFloat(); }
        if (val instanceof String) { return val.toFloat(); }
        return 0.0f;
    }

    hidden function captureStepStart() as Void {
        try {
            var info = Activity.getActivityInfo();
            if (info != null) {
                mStepStartTimer = (info.timerTime != null) ? toNum(info.timerTime) : 0;
                mStepStartDist = (info.elapsedDistance != null) ? toFlt(info.elapsedDistance) : 0.0f;
            }

            if (!(Activity has :getCurrentWorkoutStep)) { return; }
            var stepInfo = Activity.getCurrentWorkoutStep();
            if (stepInfo == null) {
                mHasStep = false;
                return;
            }
            mHasStep = true;

            var step = stepInfo.step;
            if (step has :durationType && step has :durationValue && step.durationValue != null) {
                var dt = toNum(step.durationType);
                var dv = toNum(step.durationValue);
                if (dt == 0) {
                    mIsTimeBased = true;
                    mStepDuration = dv;
                    mStepDistance = 0.0f;
                } else if (dt == 1) {
                    mIsTimeBased = false;
                    mStepDistance = dv.toFloat();
                    mStepDuration = 0;
                }
            }
        } catch (ex) {
            mHasStep = false;
        }
    }

    function compute(info as Activity.Info) as Void {
        try {
            if (!(Activity has :getCurrentWorkoutStep)) { return; }
            var stepInfo = Activity.getCurrentWorkoutStep();
            if (stepInfo == null) {
                mHasStep = false;
                mStepName = "";
                mTargetRange = "";
                mRemaining = "";
                return;
            }
            mHasStep = true;

            // Step name: notes first (Garmin puts name there), then name, then intensity
            var rawName = "";
            var step = stepInfo.step;
            try {
                if (stepInfo has :notes && stepInfo.notes != null) {
                    var n = stepInfo.notes.toString();
                    if (n.length() > 0) { rawName = n.toUpper(); }
                }
            } catch (ex2) {}
            if (rawName.length() == 0) {
                try {
                    if (stepInfo has :name && stepInfo.name != null) {
                        var n = stepInfo.name.toString();
                        if (n.length() > 0) { rawName = n.toUpper(); }
                    }
                } catch (ex3) {}
            }
            if (rawName.length() == 0) {
                rawName = intensityLabel(stepInfo.intensity);
            }

            mStepName = rawName;

            // Target range (HR or pace)
            if (step has :targetType && step has :targetValueLow && step has :targetValueHigh) {
                var tt = toNum(step.targetType);
                var lo = step.targetValueLow;
                var hi = step.targetValueHigh;
                if (lo != null && hi != null) {
                    if (tt == 0) {
                        // Speed target: values in m/s (Float), convert to pace min:sec/km
                        var loSpd = toFlt(lo);
                        var hiSpd = toFlt(hi);
                        if (loSpd > 0.0f && hiSpd > 0.0f) {
                            mTargetRange = formatPace(hiSpd) + "-" + formatPace(loSpd);
                        } else {
                            mTargetRange = "";
                        }
                    } else if (tt == 1) {
                        // HR target: values are BPM + 100
                        mTargetRange = (toNum(lo) - 100) + "-" + (toNum(hi) - 100);
                    } else {
                        mTargetRange = "";
                    }
                } else {
                    mTargetRange = "";
                }
            } else {
                mTargetRange = "";
            }

            // Remaining countdown (durationValue is seconds, timerTime is ms)
            if (mIsTimeBased && mStepDuration > 0 && info.timerTime != null) {
                var remainingMs = (mStepDuration * 1000) - (toNum(info.timerTime) - mStepStartTimer);
                var remaining = remainingMs / 1000;
                if (remaining < 0) { remaining = 0; }
                mRemaining = formatCountdown(remaining);
            } else if (!mIsTimeBased && mStepDistance > 0.0f && info.elapsedDistance != null) {
                var remaining = mStepDistance - (toFlt(info.elapsedDistance) - mStepStartDist);
                if (remaining < 0.0f) { remaining = 0.0f; }
                mRemaining = formatDistance(remaining);
            } else {
                mRemaining = "";
            }

            mColor = intensityColor(stepInfo.intensity, mStepName);
        } catch (ex instanceof Lang.Exception) {
            mHasStep = false;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        if (!mHasStep) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2,
                Graphics.FONT_TINY, "No step",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var nameFont = Graphics.FONT_MEDIUM;
        var detailFont = Graphics.FONT_MEDIUM;
        var nameH = dc.getFontHeight(nameFont);
        var detailH = dc.getFontHeight(detailFont);

        var hasDetails = (mTargetRange.length() > 0 || mRemaining.length() > 0);
        var totalH = hasDetails ? nameH + detailH + 2 : nameH;
        var y = (h - totalH) / 2;

        dc.setColor(mColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, nameFont, mStepName, Graphics.TEXT_JUSTIFY_CENTER);
        y += nameH + 2;

        if (mTargetRange.length() > 0 && mRemaining.length() > 0) {
            var detail = mTargetRange + "  " + mRemaining;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, detail, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mTargetRange.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mTargetRange, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (mRemaining.length() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, detailFont, mRemaining, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function formatCountdown(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m + ":" + s.format("%02d");
    }

    hidden function formatPace(speedMs as Float) as String {
        var paceSeconds = Math.round(1000.0f / speedMs).toNumber();
        var m = paceSeconds / 60;
        var s = paceSeconds % 60;
        return m + ":" + s.format("%02d");
    }

    hidden function formatDistance(meters as Float) as String {
        if (meters >= 1000.0f) {
            return (meters / 1000.0f).format("%.1f") + "km";
        }
        return meters.toNumber() + "m";
    }

    hidden function intensityColor(intensity, name as String) as Number {
        // Check step name first for semantic color
        if (name.find("EASY") != null || name.find("DOWNHILL") != null) { return 0x00CCFF; }

        var i = toNum(intensity);
        if (i == 2 || i == 3) { return 0x55FF55; }
        if (i == 1 || i == 4) { return 0x00CCFF; }
        return 0xFF6666;
    }

    hidden function intensityLabel(intensity) as String {
        var i = toNum(intensity);
        if (i == 2) { return "WARMUP"; }
        if (i == 3) { return "COOLDOWN"; }
        if (i == 4) { return "RECOVERY"; }
        if (i == 1) { return "REST"; }
        return "RUN";
    }
}
