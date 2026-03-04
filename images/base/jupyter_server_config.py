# images/base/jupyter_server_config.py

import jupyter_server

c = get_config()

c.ServerApp.open_browser = False

# Improve plot format support (allow saving vector graphics in notebooks).
c.InlineBackend.figure_formats = {"png", "jpeg", "svg", "pdf"}

# Don't move files into trash when deleting --- avoid taking up space.
c.FileContentsManager.delete_to_trash = False

# =============================================================================
# LSP Configuration
# =============================================================================

c.LanguageServerManager.language_servers = {
    "basedpyright": {
        "display_name": "basedpyright",
        "argv": ["basedpyright-langserver", "--stdio"],
        "languages": ["python"],
        "mime_types": ["text/x-python"],
        "version": 2,
    },

    #"ruff": {
    #    "display_name": "ruff (Linter/Formatter)",
    #    "argv": ["ruff", "server"],
    #    "languages": ["python"],
    #    "mime_types": ["text/x-python"],
    #    "version": 2,
    #},

    #"ty": {
    #    "display_name": "ty (Type Checker)",
    #    "argv": ["ty", "server"],
    #    "languages": ["python"],
    #    "mime_types": ["text/x-python"],
    #    "version": 2,
    #}
}

# =============================================================================
# `jupyter-resource-usage` Extension Config
# =============================================================================

# Enable the CPU usage tracking (disabled by default).
# NOT WORKING
#c.ResourceUseDisplay.track_cpu_percent = True

# Disable internal Prometheus metrics export to prevent UI lag (bug).
# (The setup relies on Alloy/cAdvisor for backend monitoring instead).
c.ResourceUseDisplay.enable_prometheus_metrics = False
