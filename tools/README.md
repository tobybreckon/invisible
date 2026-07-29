## Deployment and setup tools for multiple visitor account based sessions on Linux (general)

This is based on having a ``txt`` file colon seperated of ``username:password`` pairs, 1 per line - the ``accounts_file`` in the below.

This can be created from a PDF file containing lines with "Username: .. ", "Password: .. " etc which can be first processed to obtain a suitable ``accounts_file`` as follows:

```
pdftotext accounts_file.pdf
awk '
  /^Username/ {
    user = $0
    sub(/^Username[[:space:]]*:?[[:space:]]*/, "", user)
  }

  /^Password/ {
    pass = $0
    sub(/^Password[[:space:]]*:?[[:space:]]*/, "", pass)

    if (user != "") {
      print user ":" pass
      user = ""
    }
  }
' accounts_file.txt > accounts_file_colon_seperated.txt
```

### User Account Setup Tools

With your ``accounts_file`` you can then use:

```
Usage: ./run-as-users.sh <accounts_file> <command>
Example: ./run-as-users.sh accounts.txt 'whoami && id'
```

To use each of the following scipts with the above, first copy it to ``/tmp``,  then``chmod 755 /tmp/<script filename>`` and then run as:  
```
./run-as-users.sh <accounts_file> /tmp/scriptname.sh
```

```
# set up to remove all confusing start up nag messages on VS Code
./setup-vscode-empty.sh 
```

```
# set up to install python extensions on VS Code
./vscode-python-extensions-install.sh
```

```
# set up chromium as default browser (in MATE and VS Code)
set-chromium-as-default-browser.sh
```

```
# set chromium default download directoty as home directory
set-chromium-download-directory-to-home.sh
```

## LDS (Durham University) specific setup commands:

The specific setup for the excercise at [https://github.com/tobybreckon/invisible.git](https://github.com/tobybreckon/invisible.git) is thus:

```
ACCOUNTS=/path/to/accounts-file.txt
for s in setup-vscode-empty.sh vscode-python-extensions-install.sh set-chromium-as-default-browser.sh set-chromium-download-directory-to-home.sh;
do 
cp $s /tmp/;
chmod 755 /tmp/$s;
./run-as-users.sh $ACCOUNTS /tmp/$s;
done

```

Other useful commands as an _aide memoir_: 

```
./run-as-users.sh accounts.txt git clone https://github.com/tobybreckon/invisible.git

```
