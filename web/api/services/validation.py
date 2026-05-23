"""Input validation helpers for the web API."""
import re

# Names must be alphanumeric with hyphens/underscores, 1-64 chars
_SAFE_NAME_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$")

# Max file content size: 1MB
MAX_FILE_SIZE = 1_048_576


def validate_name(name: str, kind: str = "name") -> str:
    """Validate that a name is safe for use in filesystem paths.

    Raises ValueError if the name contains path separators, is empty,
    or contains other dangerous characters.
    """
    if not name or not _SAFE_NAME_RE.match(name):
        raise ValueError(
            f"Invalid {kind}: must be 1-64 alphanumeric characters "
            f"(hyphens, underscores, dots allowed, must start with alphanumeric)"
        )
    return name
