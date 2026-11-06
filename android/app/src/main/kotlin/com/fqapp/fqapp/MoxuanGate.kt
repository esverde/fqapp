package com.fqapp.fqapp

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.security.MessageDigest

/**
 * 墨卓适配版只在墨卓（Kindle 上的安卓 7.1）里用：系统包 `android` 的签名证书必须是墨卓的 platform 证书。
 * 墨卓所有正式版（1.0.0 起，各型号）都用同一套私有密钥签名，所以不挑版本、机型；APK 自己的签名、包名不变，可以从旧版覆盖升级。
 * 只防直接把 APK 装到别的设备上；源码公开（GPL），改源码重编绕得过。
 */
internal object MoxuanGate {
    // 墨卓 platform 证书（CN=kindle-android, O=esverde）的 SHA-256，PW6 的 framework-res.apk 实测
    const val PLATFORM_CERT_SHA256 = "968254ddd88548a0f296d2c6e267d30a90f6ecbb8919605db3dba324fdd0527c"

    internal fun matches(certs: List<ByteArray>): Boolean =
        certs.any { sha256Hex(it) == PLATFORM_CERT_SHA256 }

    internal fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    @Suppress("DEPRECATION") // GET_SIGNATURES：安卓 7 上只有这个
    fun isMoxuan(context: Context): Boolean = try {
        val info = context.packageManager.getPackageInfo("android", PackageManager.GET_SIGNATURES)
        matches(info.signatures?.map { it.toByteArray() }.orEmpty())
    } catch (_: Exception) {
        false
    }
}

/** 核对没过时显示的说明页：不起 Flutter、不起后端。 */
class NotMoxuanActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val pad = (24 * resources.displayMetrics.density).toInt()
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(pad, pad, pad, pad)
            addView(TextView(context).apply {
                text = "本版本是什锦铺的墨卓适配版，\n仅限在墨卓（Kindle 上的安卓）中使用。\n\n在手机上请安装什锦铺官方版。"
                textSize = 18f
                gravity = Gravity.CENTER
            })
            addView(Button(context).apply {
                text = "退出"
                setOnClickListener { finish() }
            })
        })
    }
}
