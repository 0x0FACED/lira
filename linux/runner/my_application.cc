#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

#include <cstring>

namespace {

const GtkTargetEntry kFileClipboardTargets[] = {
    {const_cast<gchar*>("text/uri-list"), 0, 0},
    {const_cast<gchar*>("x-special/gnome-copied-files"), 0, 1},
    {const_cast<gchar*>("application/x-kde-cutselection"), 0, 2},
};

void file_clipboard_get(GtkClipboard* clipboard, GtkSelectionData* selection,
                        guint info, gpointer user_data) {
  auto* copied_files = static_cast<gchar*>(user_data);
  if (info == 0) {
    // The payload is "copy\nURI"; GTK serializes the URI list with CRLF.
    gchar* uris[] = {copied_files + 5, nullptr};
    gtk_selection_data_set_uris(selection, uris);
  } else if (info == 1) {
    gtk_selection_data_set(
        selection, gtk_selection_data_get_target(selection), 8,
        reinterpret_cast<const guchar*>(copied_files),
        static_cast<gint>(std::strlen(copied_files)));
  } else if (info == 2) {
    // Dolphin/KDE: explicitly mark this as a copy, never a cut.
    const guchar copy = '0';
    gtk_selection_data_set(selection, gtk_selection_data_get_target(selection),
                           8, &copy, 1);
  }
}

void file_clipboard_clear(GtkClipboard* clipboard, gpointer user_data) {
  g_free(user_data);
}

FlMethodResponse* copy_file_to_clipboard(GtkClipboard* clipboard,
                                       FlValue* arguments) {
  if (!arguments || fl_value_get_type(arguments) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_arguments", "Expected an absolute local file path.", nullptr));
  }
  const gchar* path = fl_value_get_string(arguments);
  if (!g_path_is_absolute(path)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_arguments", "Expected an absolute local file path.", nullptr));
  }
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* filename =
      g_filename_from_utf8(path, -1, nullptr, nullptr, &error);
  if (!filename) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_arguments", error->message, nullptr));
  }
  if (!g_file_test(filename, G_FILE_TEST_EXISTS)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "file_not_found", "The file no longer exists or is inaccessible.", nullptr));
  }
  // Percent-encode the original path without resolving symlinks or duplicating it.
  g_autofree gchar* uri = g_filename_to_uri(filename, nullptr, &error);
  if (!uri) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "invalid_arguments", error->message, nullptr));
  }
  gchar* copied_files = g_strconcat("copy\n", uri, nullptr);
  if (!gtk_clipboard_set_with_data(
          clipboard, kFileClipboardTargets, G_N_ELEMENTS(kFileClipboardTargets),
          file_clipboard_get, file_clipboard_clear, copied_files)) {
    // GTK only invokes clear_func after successful ownership transfer.
    g_free(copied_files);
    return FL_METHOD_RESPONSE(fl_method_error_response_new(
        "clipboard_error", "Could not copy the file to the clipboard.", nullptr));
  }
  gtk_clipboard_set_can_store(clipboard, kFileClipboardTargets,
                              G_N_ELEMENTS(kFileClipboardTargets));
  // Persistence requires a clipboard manager/compositor that supports it;
  // in particular, Wayland does not guarantee clipboard survival after exit.
  gtk_clipboard_store(clipboard);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
}

void file_clipboard_method_call(FlMethodChannel* channel,
                                FlMethodCall* method_call, gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  if (std::strcmp(fl_method_call_get_name(method_call), "copyFile") == 0) {
    response = copy_file_to_clipboard(
        GTK_CLIPBOARD(user_data), fl_method_call_get_args(method_call));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to file clipboard call: %s", error->message);
  }
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "lira");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "lira");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) file_clipboard_codec =
      fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) file_clipboard_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "dev.0xfaced.lira/file_clipboard",
      FL_METHOD_CODEC(file_clipboard_codec));
  GtkClipboard* clipboard = gtk_clipboard_get_for_display(
      gtk_widget_get_display(GTK_WIDGET(view)), GDK_SELECTION_CLIPBOARD);
  fl_method_channel_set_method_call_handler(
      file_clipboard_channel, file_clipboard_method_call, clipboard, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
