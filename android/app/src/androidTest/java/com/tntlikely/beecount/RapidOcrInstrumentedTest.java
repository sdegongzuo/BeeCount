package com.tntlikely.beecount;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertFalse;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;

import androidx.test.platform.app.InstrumentationRegistry;

import com.benjaminwan.ocrlibrary.OcrEngine;
import com.benjaminwan.ocrlibrary.OcrResult;

import org.junit.Test;

public class RapidOcrInstrumentedTest {
    private static final String TAG = "RapidOcrInstrumented";
    private static final String SAMPLE_PATH = "/data/local/tmp/beecount_rapidocr_sample.jpg";

    @Test
    public void recognizesSampleImage() {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        Bitmap input = BitmapFactory.decodeFile(SAMPLE_PATH);
        assertNotNull("Sample image not found: " + SAMPLE_PATH, input);

        Bitmap output = input.copy(Bitmap.Config.ARGB_8888, true);
        OcrEngine engine = new OcrEngine(context);
        OcrResult result = engine.detect(input, output, 1920);
        String text = result.getStrRes() == null ? "" : result.getStrRes().trim();

        Log.i(TAG, "RapidOCR text length=" + text.length());
        Log.i(TAG, "RapidOCR text begin\n" + text + "\nRapidOCR text end");

        output.recycle();
        input.recycle();

        assertFalse("RapidOCR returned empty text", text.isEmpty());
    }
}
