package com.fqapp.fqapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MoxuanGateTest {
    @Test
    fun sha256HexIsLowercaseHex() {
        // SHA-256("abc")
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            MoxuanGate.sha256Hex("abc".toByteArray()),
        )
    }

    @Test
    fun rejectsOtherOrMissingCertificates() {
        assertFalse(MoxuanGate.matches(emptyList()))
        assertFalse(MoxuanGate.matches(listOf("not-moxuan".toByteArray())))
    }

    @Test
    fun acceptsTheMoxuanPlatformCertificate() {
        // 墨卓 platform 证书（公开证书，每个墨卓镜像的 framework-res.apk 里都有），排在别的证书后面也认
        val platform = java.util.Base64.getDecoder().decode(MOXUAN_PLATFORM_DER)
        assertTrue(MoxuanGate.matches(listOf("other".toByteArray(), platform)))
    }

    private companion object {
        const val MOXUAN_PLATFORM_DER = "MIIDhTCCAm2gAwIBAgIUY5+PyBFoVrC97ndPFXJHBurvSdgwDQYJKoZIhvcNAQEFBQAwUTELMAkGA1UEBhMCQ04xEDAOBgNVBAoMB2VzdmVyZGUxFzAVBgNVBAsMDmtpbmRsZS1hbmRyb2lkMRcwFQYDVQQDDA5raW5kbGUtYW5kcm9pZDAgFw0yNjEwMTQwMTQ0MTJaGA8yMDU0MDMwMTAxNDQxMlowUTELMAkGA1UEBhMCQ04xEDAOBgNVBAoMB2VzdmVyZGUxFzAVBgNVBAsMDmtpbmRsZS1hbmRyb2lkMRcwFQYDVQQDDA5raW5kbGUtYW5kcm9pZDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOF6E8ofwAVmojjOymngT1HzYOKsNs/xRuxdzmqjOiqIG8ep2AtdYM2ovQLjz4VJxx6O+w2e0gJVxWKsj6Tb1Ped0FPdKrZE5SoV62HTpZBVO7V/hz2uVteTSIvJ0u5ysMKyy1mZZWP9p5AitPY4w4dnk7BwFnGaCYIKvM7Fl2x1UC/90ZgXwJZRB52nZBVzS5YMpsHzJW4v6P15QrH8zxT2qKnHCmt3B2fFQ48nC6H5fgE2S2mflQNe5P1hzd9zDSgs4uiryKNwqwEsCf0IZ2HwpJdtHfPa+sQWZQFvHUdI0Fc+5dlEWBlScwJ+8/Bnk7BsDViIQkkCXVJ04LtbEgkCAwEAAaNTMFEwHQYDVR0OBBYEFPMMmkjwnt9phsLH8dRusKCvGOhOMB8GA1UdIwQYMBaAFPMMmkjwnt9phsLH8dRusKCvGOhOMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBACYq4ALrPEEhFQPC8ce2W9VnRPfiNVbQr9X3hgtd+ckLaStm2RL+HyxOULZ0AryxOl0eBRFwjOqugIfOxK/pg64qxCzhZXWptIlmEc/8AUnSufNStT+UtDW+EfcBKKrG8ciyuLEXbkKUgU1vGTqmtyijCrqicizsXGXKwdhOHTRnS6uj9TGl8fRKbIBWOjegQuQpXH3a/KclbAKxShBps8HkTOZ5aE4qmXiAEKkQgMB9Dl7RqYjo3uMXvGGjAmWNm36C2VyCIUhZelH89W6rkvfajGsNU8T+1WAcASS16ef5iDUUIUdtrXXGS4KGip/V4ENvcbhW/rYjWfl2lghGHxk="
    }
}
