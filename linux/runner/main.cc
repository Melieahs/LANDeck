#include <glib.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // webview_all_linux docks a GTK WebKit view on top of the Flutter GL
  // surface through a GtkOverlay. Under the Wayland backend that overlay is
  // composited underneath the GL surface, so the embedded page looks black.
  // XWayland composites it correctly, so prefer the X11 backend whenever an
  // X display is reachable, unless the user picked a backend explicitly.
  if (g_getenv("GDK_BACKEND") == nullptr && g_getenv("DISPLAY") != nullptr) {
    g_setenv("GDK_BACKEND", "x11", TRUE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
