package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Xml;

import org.xmlpull.v1.XmlPullParser;
import java.io.File;
import java.io.FileInputStream;
import java.util.UUID;

/** Disk acknowledgement; callers run on the plugin worker thread. */
public final class DurablePreferences {
    // Not a session record or restore policy; forces disk IO even on Android 7,
    // whose no-change commit may otherwise return true after a failed write.
    static final String COMMIT_MARKER = "__kvx_secure_storage_commit__";
    private DurablePreferences() {}

    /** SharedPreferences otherwise silently treats malformed/unreadable XML as empty. */
    public static SharedPreferences open(Context context, String name) {
        File directory = new File(context.getDataDir(), "shared_prefs");
        if (directory.exists() && (!directory.isDirectory() || !directory.canRead() || !directory.canExecute())) {
            throw new IllegalStateException("Secure storage preferences directory is unreadable");
        }
        File data = new File(directory, name + ".xml");
        File backup = new File(directory, name + ".xml.bak");
        // Match Android's recovery precedence. This check never edits either file.
        validate(backup.exists() ? backup : data);
        return context.getSharedPreferences(name, Context.MODE_PRIVATE);
    }

    private static void validate(File file) {
        if (!file.exists()) return;
        try (FileInputStream input = new FileInputStream(file)) {
            XmlPullParser parser = Xml.newPullParser();
            parser.setInput(input, "UTF-8");
            boolean rootSeen = false;
            String parent = null;
            for (int event = parser.next(); event != XmlPullParser.END_DOCUMENT; event = parser.next()) {
                if (event == XmlPullParser.START_TAG) {
                    String tag = parser.getName();
                    int depth = parser.getDepth();
                    if (depth == 1) {
                        if (rootSeen || !"map".equals(tag)) throw new IllegalStateException();
                        rootSeen = true;
                    } else if (depth == 2) {
                        if (parser.getAttributeValue(null, "name") == null) throw new IllegalStateException();
                        parent = tag;
                        String value = parser.getAttributeValue(null, "value");
                        switch (tag) {
                            case "string": case "set": break;
                            case "int": Integer.parseInt(value); break;
                            case "long": Long.parseLong(value); break;
                            case "float": Float.parseFloat(value); break;
                            case "boolean":
                                if (!"true".equals(value) && !"false".equals(value)) throw new IllegalStateException();
                                break;
                            default: throw new IllegalStateException();
                        }
                    } else if (depth != 3 || !"set".equals(parent) || !"string".equals(tag)) {
                        throw new IllegalStateException();
                    }
                } else if (event == XmlPullParser.TEXT) {
                    int depth = parser.getDepth();
                    if (depth == 2 && !"string".equals(parent) && !"set".equals(parent)) {
                        throw new IllegalStateException();
                    }
                    if (!parser.isWhitespace() && !(depth == 2 && "string".equals(parent)) && !(depth == 3 && "set".equals(parent))) {
                        throw new IllegalStateException();
                    }
                }
            }
            if (!rootSeen) throw new IllegalStateException();
        } catch (Exception error) {
            // Never include file contents or decrypted values in the exception.
            throw new IllegalStateException("Secure storage preferences are unreadable or corrupt");
        }
    }

    public static void checkedCommit(SharedPreferences.Editor editor) {
        editor.putString(COMMIT_MARKER, UUID.randomUUID().toString());
        if (!editor.commit()) {
            throw new PersistenceException();
        }
    }

    public static final class PersistenceException extends IllegalStateException {
        public PersistenceException() {
            super("Secure storage disk commit failed");
        }
    }
}
