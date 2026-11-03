package com.mxylo7.robotai;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.animation.AlphaAnimation;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebSettings;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

public class MainActivity extends Activity {
    private WebView webView;
    private FrameLayout root;
    private View splash;

    @Override public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(8, 26, 43));
        getWindow().setNavigationBarColor(Color.rgb(8, 26, 43));

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(8, 26, 43));

        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        webView.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView view, String url) {
                revealApp();
            }
        });
        webView.setWebChromeClient(new WebChromeClient());
        root.addView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));

        splash = createSplash();
        root.addView(splash, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        setContentView(root);

        webView.loadUrl("https://ajax-hup.github.io/MXYLO7-ROBOT-AI/");
    }

    private View createSplash() {
        FrameLayout screen = new FrameLayout(this);
        screen.setBackgroundColor(Color.rgb(8, 26, 43));

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setPadding(28, 28, 28, 28);

        TextView brand = new TextView(this);
        brand.setText("TREVO");
        brand.setTextColor(Color.WHITE);
        brand.setTextSize(34);
        brand.setTypeface(Typeface.create("sans-serif-black", Typeface.BOLD));
        brand.setLetterSpacing(0.12f);
        brand.setGravity(Gravity.CENTER);

        TextView sub = new TextView(this);
        sub.setText("AUTO-TRADING BOT");
        sub.setTextColor(Color.rgb(80, 217, 255));
        sub.setTextSize(17);
        sub.setTypeface(Typeface.DEFAULT_BOLD);
        sub.setLetterSpacing(0.28f);
        sub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams subParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        subParams.topMargin = 5;

        ProgressBar progress = new ProgressBar(this);
        progress.setIndeterminate(true);
        progress.setIndeterminateTintList(android.content.res.ColorStateList.valueOf(
                Color.rgb(80, 217, 255)));
        LinearLayout.LayoutParams progressParams = new LinearLayout.LayoutParams(52, 52);
        progressParams.topMargin = 38;

        TextView powered = new TextView(this);
        powered.setText("POWERED BY FR3DDY AI");
        powered.setTextColor(Color.rgb(190, 207, 220));
        powered.setTextSize(11);
        powered.setLetterSpacing(0.16f);
        powered.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams poweredParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT);
        poweredParams.topMargin = 22;

        content.addView(brand);
        content.addView(sub, subParams);
        content.addView(progress, progressParams);
        content.addView(powered, poweredParams);
        screen.addView(content, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT));
        return screen;
    }

    private void revealApp() {
        if (splash == null || splash.getVisibility() != View.VISIBLE) return;
        splash.postDelayed(() -> {
            if (splash == null || splash.getVisibility() != View.VISIBLE) return;
            AlphaAnimation fade = new AlphaAnimation(1f, 0f);
            fade.setDuration(350);
            fade.setFillAfter(true);
            splash.startAnimation(fade);
            splash.postDelayed(() -> {
                if (splash != null) {
                    root.removeView(splash);
                    splash = null;
                }
            }, 350);
        }, 900);
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
