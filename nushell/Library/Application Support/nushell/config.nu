# config.nu — loaded after env.nu

# Auto-launch tmux on interactive shells outside of tmux (mirrors .zshrc).
# `exec` replaces the nu process, so anything below this block only runs
# inside tmux (or when tmux isn't installed).
if $nu.is-interactive {
    let in_tmux = (not ($env.TMUX? | is-empty))
    let term = ($env.TERM? | default "")
    let is_tmux_term = (($term | str starts-with "screen") or ($term | str starts-with "tmux"))
    if (not $in_tmux) and (not $is_tmux_term) and (which tmux | is-not-empty) {
        exec tmux
    }
}

# Aliases
alias vim = nvim
alias nuconfig = nvim $nu.config-path
alias nuenv = nvim $nu.env-path

# --- custom commands ---

# Create a new directory and enter it
def --env mkd [dir: string] {
    mkdir $dir
    cd $dir
}

# cd to the top-most Finder window location
def --env cdf [] {
    let p = (^osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)' | str trim)
    cd $p
}

# Determine size of a file or total size of a directory
def fs [...paths: string] {
    if ($paths | is-empty) {
        ^du -sh ...(ls -a | get name)
    } else {
        ^du -sh ...$paths
    }
}

# `o` with no arguments opens cwd, otherwise opens the given paths
def o [...paths: string] {
    if ($paths | is-empty) {
        ^open .
    } else {
        ^open ...$paths
    }
}

# Tree shorthand: hidden files, color, ignore .git/node_modules, dirs first, piped to less
def tre [...args: string] {
    ^tree -aC -I '.git|node_modules|bower_components' --dirsfirst ...$args | ^less -FRNX
}

# `dig` + display only the most useful info
def digga [domain: string] {
    ^dig +nocmd $domain any +multiline +noall +answer
}

# Compare original and gzipped file size
def gz [file: path] {
    let orig = (ls $file | get 0.size | into int)
    let gzipped = (^gzip -c $file | ^wc -c | str trim | into int)
    let ratio = (($gzipped * 100.0) / $orig)
    print $"orig: ($orig) bytes"
    print $"gzip: ($gzipped) bytes \(($ratio | math round --precision 2)%\)"
}

# Show the CNs and SANs in the SSL certificate for a given domain
def getcertnames [domain: string] {
    print $"Testing ($domain)..."
    print ""
    let tmp = ("GET / HTTP/1.0\nEOT" | ^openssl s_client -connect $"($domain):443" -servername $domain err> /dev/null)
    if not ($tmp | str contains "-----BEGIN CERTIFICATE-----") {
        print "ERROR: Certificate not found."
        return
    }
    let cert_text = (
        $tmp
        | ^openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, no_serial, no_sigdump, no_signame, no_validity, no_version"
    )
    print "Common Name:"
    print ""
    print ($cert_text | ^grep "Subject:" | ^sed -e "s/^.*CN=//" -e "s/\\/emailAddress=.*//")
    print ""
    print "Subject Alternative Name(s):"
    print ""
    print ($cert_text | ^grep -A 1 "Subject Alternative Name:" | ^sed -e "2s/DNS://g" -e "s/ //g" | ^tr "," "\n" | ^tail -n +2)
}

# Create a .tar.gz archive
def targz [...paths: string] {
    let first = ($paths | first | str trim -r -c "/")
    let tmpFile = $"($first).tar"
    ^tar -cvf $tmpFile --exclude=".DS_Store" ...$paths
    let cmd = if (which pigz | is-not-empty) { "pigz" } else { "gzip" }
    let size = (ls $tmpFile | get 0.size)
    print $"Compressing .tar \(($size)\) using `($cmd)`..."
    ^$cmd -v $tmpFile
    print $"($tmpFile).gz created."
}

# Fastfetch on interactive startup
if $nu.is-interactive and (which fastfetch | is-not-empty) {
    ^fastfetch
}
