package com.it_nomads.fluttersecurestorage;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;

import com.it_nomads.fluttersecurestorage.ciphers.KeyCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherFactory;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipherImplementationGCM;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.lang.reflect.Field;
import java.io.File;
import java.nio.file.Files;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.BadPaddingException;

import org.junit.Before;
import org.junit.Test;
import org.junit.Rule;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

/** Native error propagation only. Mock preferences do not prove physical persistence. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28, manifest = Config.NONE)
public class DurableStorageTest {
    @Rule public TemporaryFolder dataDirectory = new TemporaryFolder();
    private Context context;
    private SharedPreferences preferences;
    private SharedPreferences.Editor editor;
    private StorageCipher cipher;
    private FlutterSecureStorage storage;
    private Map<String, Object> options;

    @Before
    public void setUp() throws Exception {
        context = mock(Context.class);
        when(context.getApplicationContext()).thenReturn(context);
        when(context.getDataDir()).thenReturn(dataDirectory.getRoot());
        preferences = mock(SharedPreferences.class);
        editor = mock(SharedPreferences.Editor.class, RETURNS_SELF);
        when(preferences.edit()).thenReturn(editor);
        when(editor.commit()).thenReturn(true);
        cipher = mock(StorageCipher.class);
        when(cipher.encrypt(any(byte[].class))).thenAnswer(call -> call.getArgument(0));
        options = new HashMap<>();
        options.put("resetOnError", "false");
        options.put("keyCipherAlgorithm", "RSA_ECB_OAEPwithSHA_256andMGF1Padding");
        options.put("storageCipherAlgorithm", "AES_GCM_NoPadding");
        storage = new FlutterSecureStorage(context);
        setField(storage, "config", new FlutterSecureStorageConfig(options));
        setField(storage, "preferences", preferences);
        setField(storage, "storageCipher", cipher);
    }

    @Test
    public void writeCommitFalseIsMethodErrorAndNeverSuccess() throws Exception {
        when(editor.commit()).thenReturn(false);
        MethodChannel.Result result = runMethod("write");
        verify(result).error(eq("Exception encountered"), eq("Secure storage disk commit failed"), any());
        verify(result, never()).success(any());
        verify(editor).putString(eq(storage.addPrefixToKey("session")), anyString());
        verify(editor, never()).apply();
        verify(editor, never()).remove(anyString());
        verify(editor, never()).clear();
    }

    @Test
    public void deleteCommitFalseIsMethodErrorAndNeverSuccess() throws Exception {
        when(editor.commit()).thenReturn(false);
        MethodChannel.Result result = runMethod("delete");
        verify(result).error(eq("Exception encountered"), eq("Secure storage disk commit failed"), any());
        verify(result, never()).success(any());
        verify(editor).remove(storage.addPrefixToKey("session"));
        verify(editor, never()).apply();
    }

    @Test
    public void deleteAllCommitFalseIsMethodErrorAndNeverSuccess() throws Exception {
        when(editor.commit()).thenReturn(false);
        MethodChannel.Result result = runMethod("deleteAll");
        verify(result).error(eq("Exception encountered"), eq("Secure storage disk commit failed"), any());
        verify(result, never()).success(any());
        verify(editor).clear();
        verify(editor, never()).apply();
    }

    @Test
    public void methodSuccessFollowsCommitAcknowledgement() throws Exception {
        MethodChannel.Result result = runMethod("write");
        org.mockito.InOrder order = inOrder(editor, result);
        order.verify(editor).commit();
        order.verify(result).success(null);
        verify(result, never()).error(anyString(), any(), any());
    }

    @Test
    public void failedCommitAndRepeatedFlushDeleteEachReceiveFreshMarker() throws Exception {
        when(editor.commit()).thenReturn(false, true, true);
        assertThrows(DurablePreferences.PersistenceException.class,
            () -> DurablePreferences.checkedCommit(editor));
        DurablePreferences.checkedCommit(editor);
        storage.delete(storage.addPrefixToKey("session"));
        org.mockito.ArgumentCaptor<String> marker = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(editor, times(3)).putString(eq(DurablePreferences.COMMIT_MARKER), marker.capture());
        assertEquals(3, new java.util.HashSet<>(marker.getAllValues()).size());
        org.mockito.InOrder order = inOrder(editor);
        for (String generation : marker.getAllValues()) {
            java.util.UUID.fromString(generation);
            order.verify(editor).putString(DurablePreferences.COMMIT_MARKER, generation);
            order.verify(editor).commit();
        }
        verify(editor).remove(storage.addPrefixToKey("session"));
    }

    @Test
    public void commitMarkerIsExcludedFromSessionReads() throws Exception {
        String sessionKey = storage.addPrefixToKey("session");
        String ciphertext = Base64.encodeToString("synthetic-record".getBytes(StandardCharsets.UTF_8), Base64.DEFAULT);
        Map<String, String> all = new HashMap<>();
        all.put(DurablePreferences.COMMIT_MARKER, "synthetic-marker");
        all.put(sessionKey, ciphertext);
        doReturn(all).when(preferences).getAll();
        when(cipher.decrypt(any(byte[].class))).thenAnswer(call -> call.getArgument(0));
        Map<String, String> records = storage.readAll();
        assertEquals(java.util.Collections.singletonMap("session", "synthetic-record"), records);
        assertFalse(DurablePreferences.COMMIT_MARKER.contains(
            new FlutterSecureStorageConfig(options).getSharedPreferencesKeyPrefix()));
    }

    @Test
    public void freshMarkerDefeatsOldAndroidNoChangeCommitAfterFailure() throws Exception {
        // A failure-injected model of Android 7's changed/no-change commit distinction.
        // This is algorithm/error evidence, not a physical persistence assertion.
        String key = storage.addPrefixToKey("session");
        Map<String, String> memory = new HashMap<>();
        Map<String, String> disk = new HashMap<>();
        Map<String, String> staged = new HashMap<>();
        memory.put(key, "old-session");
        disk.putAll(memory);
        java.util.concurrent.atomic.AtomicInteger physicalAttempts = new java.util.concurrent.atomic.AtomicInteger();
        when(editor.putString(anyString(), anyString())).thenAnswer(call -> {
            staged.put(call.getArgument(0), call.getArgument(1));
            return editor;
        });
        when(editor.remove(anyString())).thenAnswer(call -> {
            staged.put(call.getArgument(0), null);
            return editor;
        });
        when(editor.commit()).thenAnswer(call -> {
            Map<String, String> before = new HashMap<>(memory);
            for (Map.Entry<String, String> entry : staged.entrySet()) {
                if (entry.getValue() == null) memory.remove(entry.getKey());
                else memory.put(entry.getKey(), entry.getValue());
            }
            staged.clear();
            if (before.equals(memory)) return true;
            if (physicalAttempts.incrementAndGet() == 1) return false;
            disk.clear();
            disk.putAll(memory);
            return true;
        });
        assertThrows(DurablePreferences.PersistenceException.class, () -> storage.delete(key));
        assertFalse(memory.containsKey(key));
        assertTrue(disk.containsKey(key));
        // An ordinary repeated remove would return true without another disk attempt.
        editor.remove(key);
        assertTrue(editor.commit());
        assertTrue(disk.containsKey(key));
        assertEquals(1, physicalAttempts.get());
        // The production retry inserts a fresh marker, forcing a changed generation.
        storage.delete(key);
        assertFalse(disk.containsKey(key));
        assertEquals(2, physicalAttempts.get());
    }

    @Test
    public void metadataFlushFailureAbortsCipherFactory() {
        when(editor.commit()).thenReturn(false);
        assertThrows(DurablePreferences.PersistenceException.class,
            () -> new StorageCipherFactory(preferences,
                "RSA_ECB_OAEPwithSHA_256andMGF1Padding", "AES_GCM_NoPadding",
                new FlutterSecureStorageConfig(options)));
        verify(editor).commit();
        verify(editor, never()).putString(eq("FlutterSecureSAlgorithmKey"), anyString());
        verify(editor, never()).putString(eq("FlutterSecureSAlgorithmStorage"), anyString());
        verify(editor, never()).apply();
    }

    @Test
    public void algorithmMarkerCommitFailurePropagates() throws Exception {
        StorageCipherFactory factory = new StorageCipherFactory(preferences,
            "RSA_ECB_OAEPwithSHA_256andMGF1Padding", "AES_GCM_NoPadding",
            new FlutterSecureStorageConfig(options));
        setField(storage, "storageCipherFactory", factory);
        when(editor.commit()).thenReturn(false);
        java.lang.reflect.Method update = FlutterSecureStorage.class.getDeclaredMethod(
            "updateAlgorithmMarkers", SharedPreferences.class);
        update.setAccessible(true);
        java.lang.reflect.InvocationTargetException error = assertThrows(
            java.lang.reflect.InvocationTargetException.class, () -> update.invoke(storage, preferences));
        assertTrue(error.getCause() instanceof DurablePreferences.PersistenceException);
        verify(editor).putString(eq("FlutterSecureSAlgorithmKey"), anyString());
        verify(editor).putString(eq("FlutterSecureSAlgorithmStorage"), anyString());
        verify(editor, never()).apply();
    }

    @Test
    public void wrappedKeyCreationCommitFailureAbortsCipherConstruction() throws Exception {
        when(context.getSharedPreferences(eq("FlutterSecureKeyStorage"), anyInt())).thenReturn(preferences);
        when(editor.commit()).thenReturn(true, false);
        KeyCipher keyCipher = mock(KeyCipher.class);
        when(keyCipher.wrap(any())).thenReturn(new byte[] {1, 2, 3});
        assertThrows(DurablePreferences.PersistenceException.class,
            () -> new StorageCipherImplementationGCM(context, keyCipher, null));
        verify(keyCipher).wrap(any());
        verify(editor, times(2)).commit();
        verify(editor, never()).apply();
    }

    @Test
    public void wrappedKeyRetryMustFlushBeforeUnwrappingMemoryValue() throws Exception {
        when(context.getSharedPreferences(eq("FlutterSecureKeyStorage"), anyInt())).thenReturn(preferences);
        when(preferences.getString(anyString(), isNull())).thenReturn(
            Base64.encodeToString(new byte[] {1, 2, 3}, Base64.DEFAULT));
        KeyCipher keyCipher = mock(KeyCipher.class);
        when(keyCipher.unwrap(any(byte[].class), eq("AES")))
            .thenReturn(new javax.crypto.spec.SecretKeySpec(new byte[16], "AES"));
        when(editor.commit()).thenReturn(false);
        assertThrows(DurablePreferences.PersistenceException.class,
            () -> new StorageCipherImplementationGCM(context, keyCipher, null));
        verify(keyCipher, never()).unwrap(any(byte[].class), anyString());
        when(editor.commit()).thenReturn(true);
        clearInvocations(editor, keyCipher);
        new StorageCipherImplementationGCM(context, keyCipher, null);
        org.mockito.InOrder order = inOrder(editor, keyCipher);
        order.verify(editor).commit();
        order.verify(keyCipher).unwrap(any(byte[].class), eq("AES"));
        verify(keyCipher, never()).wrap(any());
    }

    @Test
    public void wrappedKeyDeletionCommitFailurePropagates() throws Exception {
        when(context.getSharedPreferences(eq("FlutterSecureKeyStorage"), anyInt())).thenReturn(preferences);
        KeyCipher keyCipher = mock(KeyCipher.class);
        when(keyCipher.wrap(any())).thenReturn(new byte[] {1, 2, 3});
        StorageCipherImplementationGCM gcm = new StorageCipherImplementationGCM(context, keyCipher, null);
        when(editor.commit()).thenReturn(false);
        assertThrows(DurablePreferences.PersistenceException.class, () -> gcm.deleteKey(context));
        verify(editor).remove(anyString());
        verify(editor, never()).apply();
    }

    @Test
    public void corruptCiphertextWithResetDisabledIsMethodErrorWithoutDeletion() throws Exception {
        String key = storage.addPrefixToKey("session");
        when(preferences.contains(key)).thenReturn(true);
        when(preferences.getString(key, null)).thenReturn(Base64.encodeToString(
            "corrupt-ciphertext".getBytes(StandardCharsets.UTF_8), Base64.DEFAULT));
        when(cipher.decrypt(any(byte[].class))).thenThrow(new BadPaddingException("Unreadable encrypted session"));
        MethodChannel.Result result = runMethod("read");
        verify(result).error(eq("Exception encountered"), eq("Unreadable encrypted session"), any());
        verify(result, never()).success(any());
        verify(preferences, never()).edit();
        verify(editor, never()).clear();
        verify(editor, never()).remove(anyString());
    }

    @Test
    public void initializationCommitFailureClearsCacheAndRetryActuallyReinitializes() throws Exception {
        storage = new FlutterSecureStorage(context);
        when(context.getSharedPreferences(anyString(), anyInt())).thenReturn(preferences);
        when(preferences.getBoolean("ENCRYPTED_PREFERENCES_MIGRATED", false)).thenReturn(true);
        when(preferences.getAll()).thenReturn(java.util.Collections.emptyMap());
        // Flush config, construct factory, then fail writing markers after prefs were cached.
        when(editor.commit()).thenReturn(true, true, false, true, true, false);
        SecurePreferencesCallback<Void> first = callback();
        storage.initialize(new FlutterSecureStorageConfig(options), first);
        verify(first).onError(isA(DurablePreferences.PersistenceException.class));
        verify(first, never()).onSuccess(any());
        assertNull(getField(storage, "preferences"));
        assertNull(getField(storage, "storageCipher"));
        assertNull(getField(storage, "storageCipherFactory"));
        SecurePreferencesCallback<Void> retry = callback();
        storage.initialize(new FlutterSecureStorageConfig(options), retry);
        verify(retry).onError(isA(DurablePreferences.PersistenceException.class));
        verify(retry, never()).onSuccess(any());
        verify(context, times(2)).getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE);
        verify(context, times(2)).getSharedPreferences("FlutterSecureStorageConfiguration", Context.MODE_PRIVATE);
        verify(editor, times(6)).commit();
    }

    @Test
    public void initializationFailureIsMethodErrorWithoutOperationExecution() throws Exception {
        storage = new FlutterSecureStorage(context);
        when(context.getSharedPreferences(anyString(), anyInt())).thenReturn(preferences);
        when(editor.commit()).thenReturn(false);
        MethodChannel.Result result = runMethod("write");
        verify(result).error(eq("Exception encountered"), eq("Secure storage disk commit failed"), any());
        verify(result, never()).success(any());
        verify(editor, never()).putString(eq(new FlutterSecureStorageConfig(options).getSharedPreferencesKeyPrefix() + "_session"), anyString());
    }


    @Test
    public void malformedSessionBackingXmlIsErrorAndPreserved() throws Exception {
        assertMalformedXmlPreserved("FlutterSecureStorage");
    }

    @Test
    public void malformedConfigurationBackingXmlIsErrorAndPreserved() throws Exception {
        assertMalformedXmlPreserved("FlutterSecureStorageConfiguration");
    }

    @Test
    public void malformedWrappedKeyBackingXmlIsErrorAndPreserved() throws Exception {
        assertMalformedXmlPreserved("FlutterSecureKeyStorage");
    }

    @Test
    public void validBackupWinsOverMalformedMainXml() throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        writeText(new File(directory, "FlutterSecureStorage.xml").toPath(), "<broken");
        writeText(new File(directory, "FlutterSecureStorage.xml.bak").toPath(),
            "<?xml version=\"1.0\" encoding=\"utf-8\"?><map><string name=\"record\">ciphertext</string></map>");
        when(context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)).thenReturn(preferences);
        assertSame(preferences, DurablePreferences.open(context, "FlutterSecureStorage"));
    }

    @Test
    public void malformedBackupWinsOverValidMainAndMustFail() throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        writeText(new File(directory, "FlutterSecureStorage.xml").toPath(), "<map></map>");
        File backup = new File(directory, "FlutterSecureStorage.xml.bak");
        writeText(backup.toPath(), "<broken");
        assertThrows(IllegalStateException.class,
            () -> DurablePreferences.open(context, "FlutterSecureStorage"));
        assertEquals("<broken", readText(backup.toPath()));
        verify(context, never()).getSharedPreferences(anyString(), anyInt());
    }

    @Test
    public void wellFormedXmlWithInvalidPreferenceValueIsRejectedAndPreserved() throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        File file = new File(directory, "FlutterSecureStorageConfiguration.xml");
        String xml = "<map><int name=\"marker\" value=\"not-an-integer\"/></map>";
        writeText(file.toPath(), xml);
        IllegalStateException error = assertThrows(IllegalStateException.class,
            () -> DurablePreferences.open(context, "FlutterSecureStorageConfiguration"));
        assertEquals("Secure storage preferences are unreadable or corrupt", error.getMessage());
        assertNull(error.getCause());
        assertEquals(xml, readText(file.toPath()));
        verify(context, never()).getSharedPreferences(anyString(), anyInt());
    }

    @Test
    public void invalidXmlShapeDoesNotLeakInputInStorageError() throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        File file = new File(directory, "FlutterSecureStorage.xml");
        String[] invalidXml = {
            "<map><int name=\"marker\" value=\"1\">private-input-sentinel</int></map>",
            "<map>private-input-sentinel</map>",
            "<map><int name=\"marker\" value=\"1\"> </int></map>",
            "<map><unknown name=\"private-input-sentinel\"/></map>"
        };
        for (String xml : invalidXml) {
            writeText(file.toPath(), xml);
            IllegalStateException error = assertThrows(IllegalStateException.class,
                () -> DurablePreferences.open(context, "FlutterSecureStorage"));
            assertEquals("Secure storage preferences are unreadable or corrupt", error.getMessage());
            assertNull(error.getCause());
            assertFalse(error.toString().contains("private-input-sentinel"));
            assertEquals(xml, readText(file.toPath()));
        }
        verify(context, never()).getSharedPreferences(anyString(), anyInt());
    }

    @Test
    public void validPreferenceMapIsAccepted() throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        File file = new File(directory, "FlutterSecureStorageConfiguration.xml");
        writeText(file.toPath(), "<map>"
            + "<boolean name=\"migrated\" value=\"true\"/>"
            + "<int name=\"version\" value=\"1\"/>"
            + "<long name=\"timestamp\" value=\"2\"/>"
            + "<float name=\"number\" value=\"1.5\"/>"
            + "<set name=\"profiles\"><string>profile</string></set>"
            + "<string name=\"algorithm\">AES_GCM_NoPadding</string></map>");
        when(context.getSharedPreferences("FlutterSecureStorageConfiguration", Context.MODE_PRIVATE))
            .thenReturn(preferences);
        assertSame(preferences, DurablePreferences.open(context, "FlutterSecureStorageConfiguration"));
    }

    @Test
    public void malformedBackingXmlStartupIsMethodErrorWithoutNullSuccess() throws Exception {
        storage = new FlutterSecureStorage(context);
        File directory = dataDirectory.newFolder("shared_prefs");
        File file = new File(directory, "FlutterSecureStorage.xml");
        writeText(file.toPath(), "<broken");
        MethodChannel.Result result = runMethod("read");
        verify(result).error(eq("Exception encountered"), anyString(), any());
        verify(result, never()).success(any());
        assertEquals("<broken", readText(file.toPath()));
        verify(context, never()).getSharedPreferences(anyString(), anyInt());
    }

    private void assertMalformedXmlPreserved(String name) throws Exception {
        File directory = dataDirectory.newFolder("shared_prefs");
        File file = new File(directory, name + ".xml");
        writeText(file.toPath(), "<broken");
        assertThrows(IllegalStateException.class, () -> DurablePreferences.open(context, name));
        assertEquals("<broken", readText(file.toPath()));
        verify(context, never()).getSharedPreferences(anyString(), anyInt());
    }

    private static void writeText(java.nio.file.Path path, String text) throws java.io.IOException {
        Files.write(path, text.getBytes(StandardCharsets.UTF_8));
    }

    private static String readText(java.nio.file.Path path) throws java.io.IOException {
        return new String(Files.readAllBytes(path), StandardCharsets.UTF_8);
    }

    private MethodChannel.Result runMethod(String method) throws Exception {
        FlutterSecureStoragePlugin plugin = new FlutterSecureStoragePlugin();
        setField(plugin, "secureStorage", storage);
        Map<String, Object> args = new HashMap<>();
        args.put("options", options);
        args.put("key", "session");
        args.put("value", "synthetic-session-record");
        MethodChannel.Result result = mock(MethodChannel.Result.class);
        plugin.new MethodRunner(new MethodCall(method, args), result).run();
        return result;
    }

    @SuppressWarnings("unchecked")
    private static SecurePreferencesCallback<Void> callback() {
        return mock(SecurePreferencesCallback.class);
    }

    private static void setField(Object target, String name, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(name);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static Object getField(Object target, String name) throws Exception {
        Field field = target.getClass().getDeclaredField(name);
        field.setAccessible(true);
        return field.get(target);
    }
}
