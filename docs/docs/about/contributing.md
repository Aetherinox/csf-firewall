---
title: Contributing to CSF-Firewall
tags:
  - info
---

<div align="center" markdown="1">
<h1>♾️ Contributing ♾️</h1>

<br />

<p align="center" markdown="1">

<!-- prettier-ignore-start -->
[![Version][github-version-img]][github-version-uri]
[![Downloads][github-downloads-img]][github-downloads-uri]
[![Size][github-size-img]][github-size-img]
[![Last Commit][github-commit-img]][github-commit-img]
[![Contributors][contribs-all-img]](#)
<!-- prettier-ignore-end -->

</p>

</div>

<br />

---

<br />

## About

Below are a list of ways that you can help contribute to this project, as well as policies and guides that explain how to get started.

Please review everything on this page before you submit your contribution.

<br />

---

<br />

## Issues, Bugs, Ideas

Stuff happens, and sometimes as best as we try, there may be issues within this project that we are unaware of. That is the great thing about open-source; anyone can use the program and contribute to making it better.

<br />

If you have found a bug, have an issue, or maybe even a cool idea; you can let us know by [submitting it](https://github.com/aetherinox/csf-firewall/issues). However, before you submit your new issue, bug report, or feature request; head over to the [Issues Section](https://github.com/aetherinox/csf-firewall/issues) and ensure nobody else has already submitted it.

<br />

Once you are sure that your issue has not already being dealt with; you may submit a new issue at [here](https://github.com/aetherinox/csf-firewall/issues/new/choose). You'll be asked to specify exactly what your new submission targets, such as:
- Bug report
- Feature Suggestion

<br />

When writing a new submission; ensure you fill out any of the questions asked of you. If you do not provide enough information, we cannot help. Be as detailed as possible, and provide any logs or screenshots you may have to help us better understand what you mean. Failure to fill out the submission properly may result in it being closed without a response.

<br />

If you are submitting a bug report:

- Explain the issue
- Describe how you expect for a feature to work, and what you're seeing instead of what you expected.
- List possible options for a resolution or insight
- Provide screenshots, logs, or anything else that can visually help track down the issue.

<br />

<div align="center" markdown="1">

[![Submit Issue][btn-github-submit-img]][btn-github-submit-uri]

</div>

<br />

<div align="center" markdown="1">

**[`^        back to top        ^`](#about)**

</div>

<br />

---

<br />

## Contributing

If you are looking to contribute to this project by actually submit your own code; please review this section completely. There is important information and policies provided below that you must follow for your pull request to get accepted.

The source is here for everyone to collectively share and collaborate on. If you think you have a possible solution to a problem; don't be afraid to get your hands dirty.

All contributions are made via pull requests. To create a pull request, you need a GitHub account. If you are unclear on this process, see [GitHub's documentation on forking and pull requests](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork). Pull requests should be targeted at the master branch.

<br />

### Before Submitting Pull Requests

- Follow the repository's code formatting conventions (see below);
- Include tests that prove that the change works as intended and does not add regressions;
- Document the changes in the code and/or the project's documentation;
- Your PR must pass the CI pipeline;
- When submitting your Pull Request, use one of the following branches:
  - For bug fixes: `main` branch
  - For features & functionality: `development` branch
- Include a proper git commit message following the [Conventional Commit Specification](https://conventionalcommits.org/en/v1.0.0/#specification).

<br />

If you have completed the above tasks, the pull request is ready to be reviewed and your pull request's label will be changed to "Ready for Review". At this point, a human will need to step in and manually verify your submission.

Reviewers will approve the pull request once they are satisfied with the patch it will be merged.

<br />

### Conventional Commit Specification

When committing your changes, we require you to follow the [Conventional Commit Specification](https://conventionalcommits.org/en/v1.0.0/#specification). The **Conventional Commits** is a specification for the format and content of a commit message. The concept behind Conventional Commits is to provide a rich commit history that can be read and understood by both humans and automated tools. Conventional Commits have the following format:

<br />

```
<type>[(optional <scope>)]: <description>

[optional <body>]

[optional <footer(s)>]
```

<br />

#### Types

Our repositories make use of the following commit tags:

<br />

| Type | Description |
| --- | --- |
| `feat` | Introduce new feature |
| `fix` | Bug fix |
| `chore` | Includes technical or preventative maintenance task that is necessary for managing the app or repo, such as updating grunt tasks, but is not tied to any specific feature. Usually done for maintenance purposes.<br/>E.g: Edit .gitignore, .prettierrc, .prettierignore, .gitignore, eslint.config.js file |
| `revert` | Revert a previous commit |
| `style` | Update / reformat style of source code. Does not change the way app is implemented. Changes that do not affect the meaning of the code<br />E.g: white-space, formatting, missing semi-colons, change tabs to spaces, etc) |
| `docs` | Change website or markdown documents. Does not mean changes to the documentation generator script itself, only the documents created from the generator. <br/>E.g: documentation, readme.md or markdown |
| `build` | Changes to the build / compilation / packaging process or auxiliary tools such as doc generation<br />E.g: create new build tasks, update release script, etc. |
| `refactor` | Change to production code that leads to no behavior difference,<br/>E.g: split files, rename variables, rename package, improve code style, etc. |
| `test` | Add or refactor tests, no production code change. Changes the suite of automated tests for the app. |
| `ci` | Changes related to Continuous Integration (usually `yml` and other configuration files). |
| `perf` | Performance improvement of algorithms or execution time of the app. Does not change an existing feature. |

<br />

##### Example 1:

```
feat(core): bug affecting menu [#22]
^───^────^  ^─────────────────^  ^───^
|   |       |                  |
|   |       |                  └─⫸ (ISSUE):   Reference issue ID
│   │       │
│   │       └──────────────────────⫸ (DESC):   Summary in present tense. Use lower case not title case!
│   │
│   └──────────────────────────────⫸ (SCOPE):  The package(s) that this change affects
│
└──────────────────────────────────⫸ (TYPE):   See list above
```

<br />

##### Example 2:

```
<type>(<scope>): <short summary> [issue]
  |       |             |           |
  |       |             |           └─⫸ Reference issue id (optional)
  │       │             │
  │       │             └─⫸ Summary in present tense. Not capitalized. No period at the end.
  │       │
  │       └─⫸ Commit Scope: animations|bazel|benchpress|common|compiler|compiler-cli|core|
  │                          elements|forms|http|language-service|localize|platform-browser|
  │                          platform-browser-dynamic|platform-server|router|service-worker|
  │                          upgrade|zone.js|packaging|changelog|docs-infra|migrations|ngcc|ve|
  │                          devtools....
  │
  └─⫸ Commit Type: build|ci|doc|docs|feat|fix|perf|refactor|test
                    website|chore|style|type|revert|deprecate
```

<br />
<br />

### Committing

If you are pushing a commit which addresses a submitted issue, reference your issue at the end of the commit message. You may also optionally add the major issue to the end of your commit body.

References should be on their own line, following the word `Ref` or `Refs`

```
Title:          fix(core): fix error message displayed to users. [#22]
Description:    The description of your commit

                Ref: #22, #34, #37
```

<br />
<br />

### Languages

The formatting of code greatly depends on the language being used for this repository. We provide various different languages below as this guide is utilized across multiple repositories.

- [Perl](#perl)
- [Python](#python)
- [Javascript / Typescript / NodeJS](#nodejs)

<br />
<br />

#### Perl

The following guidelines apply to any projects written with Perl:

<br />
<br />

##### Indentation

Use `4 spaces` per indentation level.

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        if (scalar(keys %versions) == 0)
        {
            if ($DEBUG)
            {
                dbg("=== csget: No version files to fetch — exiting ===\n");
            }

            my $status_file = "/var/lib/configserver/last_run_no_versions";
            if (!-d "/var/lib/configserver")
            {
                system("mkdir -p /var/lib/configserver") == 0
                    or die "Failed to create /var/lib/configserver for status file";
            }

            system("touch $status_file") == 0
                or warn "Failed to create status file $status_file";

            exit 0;
        }
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        if (scalar(keys %versions) == 0)
        {
            if ($DEBUG)
            {
            dbg("=== csget: No version files to fetch — exiting ===\n");
            }

            my $status_file = "/var/lib/configserver/last_run_no_versions";
            if (!-d "/var/lib/configserver")
            {
              system("mkdir -p /var/lib/configserver") == 0
              or die "Failed to create /var/lib/configserver for status file";
            }

            system("touch $status_file") == 0
            or warn "Failed to create status file $status_file";

            exit 0;
        }
        ```

<br />
<br />

##### Line Length

Keep the maximum character count to `100 characters per line`. If you are revising old code which doesn't follow this guideline; please rewrite it to conform.

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        # Each line is under 100 characters
        my $status_file = "/var/lib/configserver/last_run_no_versions";
        system("mkdir -p /var/lib/configserver") == 0
            or die "Failed to create /var/lib/configserver for status file";
        dbg("=== csget: No version files to fetch — exiting ===\n");
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        # Lines exceed 100 characters
        my $status_file = "/var/lib/configserver/last_run_no_versions"; 
        system("mkdir -p /var/lib/configserver") == 0 or die "Failed to create /var/lib/configserver for status file"; dbg("=== csget: No version files to fetch — exiting ===\n");
        ```

<br />
<br />

##### Blank Lines

Surround top-level functions and class definitions with a blank line in-between.

Method definitions inside a class are surrounded by a single blank line.

Extra blank lines may be used (sparingly) to separate groups of functions related to one another. Blank lines may be omitted between a bunch of related one-liners (e.g: set of dummy implementations).

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        # Top-level functions separated by blank lines

        sub fetch_versions
        {
            # fetch versions logic
            dbg("Fetching versions...\n");
        }

        sub check_versions
        {
            # check versions logic
            dbg("Checking versions...\n");
        }

        # Methods inside a package/class with single blank lines in-between
        package MyClass;

        sub new
        {
            my ($class) = @_;
            bless {}, $class;
        }

        sub run
        {
            dbg("Running...\n");
        }

        sub stop
        {
            dbg("Stopping...\n");
        }
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        # Top-level functions crammed together
        sub fetch_versions
        {
            dbg("Fetching versions...\n");
        }
        sub check_versions
        {
            dbg("Checking versions...\n");
        }

        # Methods inside a package/class with no spacing
        package MyClass;
        sub new
        {
            my ($class) = @_;
            bless {}, $class;
        }
        sub run
        {
            dbg("Running...\n");
        }
        sub stop
        {
            dbg("Stopping...\n");
        }
        ```

<br />
<br />

##### Imports

When importing modules using `use` and `require`, try to observe the following:

- No namespace polluting, only include what you need
- Use `require` for modules that are needed conditionally at runtime.
- Prefer `use` for compile-time imports when possible, often safter and catches errors early.
- Keep imports at the top of the file for clarity.
- Use fully qualified names when you don’t need to import symbols.
- Group related imports together and separate core, CPAN, and local modules for readability.
- Avoid importing entire modules with use Module; unless you truly need everything.
- Document any unusual or non-standard imports so readers understand why they are used.

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        # Only import what is needed, keep imports organized
        use strict;
        use warnings;
        use File::Path qw(make_path);   # Only import make_path function
        use List::Util qw(sum max);     # Only import specific functions

        # Local module import with fully qualified usage
        use My::Utils;                  # We'll call functions as My::Utils::function()
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        # Polluting namespace by importing everything
        use File::Path;                 # Imports all functions, even if not used
        use List::Util;                 # Imports all functions unnecessarily

        # Mixing local and CPAN imports randomly in middle of code
        require My::Utils;              # Not at top of file
        my $result = My::Utils::calculate(); 
        ```

<br />
<br />

##### Commenting

Comment your code. It helps novice readers to better understand the process. It doesn't have to be painfully obvious explanations, but it helps to give an idea of what something does. Explanations should be quick
and to the point.

Do not include comments above functions that basically say the name of the function all over again.

Please append `#` to the beginning of each line.

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        # #
        #   Daemonize / fork the script when not in debug mode
        #       sudo perl -w /etc/cron.daily/csget --nosleep
        #       sudo perl -d /etc/cron.daily/csget
        #   
        #   - Forks the process: parent exits, freeing the terminal or cron
        #   - Child process continues running in the background
        #   - Changes working directory to root to avoid locking any directory
        #   - Closes standard filehandles (STDIN, STDOUT, STDERR) for background operation
        #   - Redirects STDIN from /dev/null
        #   - Redirects STDOUT and STDERR to the daemon log file
        #   - Ensures that all output/errors from the daemon are captured in the log
        # #

        unless ($DEBUG)
        {
            if (my $pid = fork) { exit 0; }         # parent
            elsif (defined($pid)) { $pid = $$; }    # child
            else { die "Unable to fork: $!"; }      # cannot fork

            chdir("/");
            close(STDIN);
            close(STDOUT);
            close(STDERR);
            open(STDIN,  "<", "/dev/null");
            open(STDOUT, ">>", "$log_daemon")
                or die "Cannot open STDOUT log: $!";
            open(STDERR, ">>", "$log_daemon")
                or die "Cannot open STDERR log: $!";
        }
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        # #
        #   does not run in debug mode
        # #

        unless ($DEBUG)
        {
            if (my $pid = fork) { exit 0; }
            elsif (defined($pid)) { $pid = $$; }
            else { die "Unable to fork: $!"; }

            chdir("/");
            close(STDIN);
            close(STDOUT);
            close(STDERR);
            open(STDIN,  "<", "/dev/null");
            open(STDOUT, ">>", "$log_daemon")
                or die "Cannot open STDOUT log: $!";
            open(STDERR, ">>", "$log_daemon")
                or die "Cannot open STDERR log: $!";
        }
        ```

        <br />

        Just repeating the information over again:

        ```perl
        # #
        #   calculates numbers
        # #
    
        sub calculate_sum
        {
            my ($a, $b) = @_;
            return $a + $b;
        }
        ```

<br />
<br />

##### Casing

- Use `camelCase` for variable and object names
    - _e.g: userName, totalCount_
- Functions should start with an uppercase letter (PascalCase) if following project convention
    - _e.g: CalculateSum()_
- Enums and constants should be capitalized or use ALL_CAPS
    - _e.g: STATUS_ACTIVE, ColorRed_
- When reviewing code, if you encounter names that do not follow this convention, update them in your pull request to maintain consistency.

<br />

=== "✅ Correct"

    !!! success ""

        ```perl
        my $userName = "Aetherinox";        # camelCase variable
        my $totalCount = 42;                # camelCase variable

        sub CalculateSum                    # Function starts with uppercase
        {
            my ($a, $b) = @_;
            return $a + $b;
        }

        use constant STATUS_ACTIVE => 1;    # Enum/constant capitalized
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```perl
        my $User_name = "Aetherinox";       # Underscores + incorrect capitalization
        my $totalcount = 42;                # Missing camelCase

        sub calculate_sum                   # Function starts with lowercase
        {
            my ($a, $b) = @_;
            return $a + $b;
        }

        use constant status_active => 1;    # Enum/constant not capitalized
        ```

<br />
<br />
<br />

#### Python

The following guidelines apply to any projects written with Python:

<br />

##### Indentation

Use `4 spaces` per indentation level.

<br />

=== "✅ Correct"

    !!! success ""

        ```python
        def Encrypt( key : int, bytestr : bytes ):
            res = b''
            i_blk, left_bytes = divmod( len(bytestr), 3 )
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```python
        def Encrypt( key : int, bytestr : bytes ):
        res = b''
        i_blk, left_bytes = divmod( len(bytestr), 3 )
        ```

<br />

##### Line Length

Keep the maximum character count to `100 characters per line`. If you are revising old code which doesn't follow this guideline; please rewrite it to conform.

<br />

=== "✅ Correct"

    !!! success ""

        ```python
        import requests

        # Long URL split across multiple lines using parentheses
        def fetch_user_data(user_id: str) -> dict:
            response = requests.get(
                f"https://api.example.com/users/{user_id}/details?"
                f"include=posts,comments,likes,shares"
            )
            return response.json()

        # Using backslash for line continuation (less preferred, usually for long strings)
        def build_command() -> str:
            long_command = "python script.py --option1 value1 --option2 value2 --option3 value3 " \
                          "--option4 value4 --option5 value5"
            return long_command
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```python
        import requests

        # URL is way too long on a single line, exceeds 100 characters
        def fetch_user_data(user_id: str) -> dict:
            response = requests.get(f"https://api.example.com/users/{user_id}/details?include=posts,comments,likes,shares")
            return response.json()

        # Long shell command all in one line, very hard to read
        def build_command() -> str:
            long_command = "python script.py --option1 value1 --option2 value2 --option3 value3 --option4 value4 --option5 value5"
            return long_command
        ```

<br />
<br />

##### Blank Lines

Surround top-level functions and class definitions with a blank line in-between.

Method definitions inside a class are surrounded by a single blank line.

Extra blank lines may be used (sparingly) to separate groups of functions related to one another. Blank lines may be omitted between a bunch of related one-liners (e.g: set of dummy implementations).

<br />

=== "✅ Correct"

    !!! success ""

        ```python
        # #
        #   Top-level function with a blank line before and after
        # #
    
        def initialize_server():
            print("Server initialized")


        def shutdown_server():
            print("Server shutdown")


        class ServerManager:

            # #
            #   Method inside a class separated by a single blank line#
            # #
    
            def start(self):
                print("Starting server")

            def stop(self):
                print("Stopping server")
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```python
        def initialize_server():
            print("Server initialized")
        def shutdown_server():
            print("Server shutdown")
        class ServerManager:
            def start(self):
                print("Starting server")
            def stop(self):
                print("Stopping server")
        ```

<br />
<br />

##### Imports

Imports should usually be on separate lines:

<br />

=== "✅ Correct"

    !!! success ""

        ```python
        import os
        import sys
        ```

        ```python
        from mypkg import (
            siblingA,
            siblingB,
            siblingC,
        )
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```python
        import sys, os
        ```

        ```python
        from mypkg import siblingA
        from mypkg import siblingB
        from mypkg import siblingC
        ```

        ```python
        from mypkg import siblingA, siblingB, siblingC
        ```

<br />

##### Commenting

Please follow these guidelines for commenting:

- Use comments to explain why something is done, not what is obvious from the code.
- Keep comments concise and clear.
- Do not repeat the function name or code in the comment.
- Block comments should be used to give a brief explanation of something to note as a developer.
- Docstrings should be used when writing important descriptions, arguments usage, etc.
- Wrap block comments in `#`, two on top, two on bottom, one per comment line.

<br />

=== "✅ Correct"

    !!! success ""

        ```python
        # #
        #   Docstring Example
        # #
  
        def fetch_user_data(user_id: str) -> dict:
            """
            Fetches user data from the API.

            Args:
                user_id (str): The unique identifier for the user.

            Returns:
                dict: JSON data containing user information such as
                      'name', 'email', 'posts', and 'comments'.

            Raises:
                requests.RequestException: If the API call fails.
            """
            import requests
            response = requests.get(f"https://api.example.com/users/{user_id}")
            response.raise_for_status()
            return response.json()
        ```

=== "❌ Incorrect"

    !!! failure ""

        ```python
        def fetch_user_data(user_id: str) -> dict:
            """Fetch user data"""
            import requests
            response = requests.get(f"https://api.example.com/users/{user_id}")
            return response.json()  # return data
        ```

<br />
<br />

##### Casing

- Stick to `camelCase`; unless:
  - naming functions, capitalize the first letter
  - Capitalize enums
- If you see code not conforming with this, please revise it in your pull request.

<br />

> [!TIP]
> ✅ Correct
> ```python
> def Encrypt( key : int, byteStr : bytes ):
>     res = b''
>     iBlock, leftBytes = divmod( len(byteStr), 3 )
> ```

<br />

> [!CAUTION]
> ❌ Wrong
> ```python
> def encrypt( key : int, bytestr : bytes ):
>     res = b''
>     i_blk, left_bytes = divmod( len(bytestr), 3 )
> ```

<br />

<br />

<div align="center" markdown="1">

**[`^        back to top        ^`](#about)**

</div>

<br />

---

<br />

#### NodeJS

The following allows you to configure ESLint and Prettier.

<br />
<br />

##### Prettier

We have opted to make use of [ESLint](#eslint) over Prettier. We provide a detailed ESLint flag config file with very specific linting rules. Please review that section for more information.

<br />
<br />

##### ESLint

Within the root folder of the repo, there are several configuration files which you should be using within the project. These files dictate how prettier and eslint will behave and what is acceptable / not acceptable.

<br />

Pick the config file below depending on which version of ESLint you are using. The v8 and older `.eslint` may not be there if we have migrated over to an Eslint v9 flat config file:

<br />

###### v9 & Newer (Config)

Our NodeJS applications require that you utilize ESLint v9 or newer which makes use of a flat config structure. You may find a copy of our flat config at the link below:

- [📄 eslint.config.mjs](https://github.com/aetherinox/csf-firewall/blob/main/eslint.config.mjs)

<br />

###### v8 & Older (Config)

- We no longer utilize any version of ESLint older than version 9.

<br />
<br />

!!! note

    When submitting your pull request, these linting and style rules will be verified with all of your files. 
    If you did not follow these rules; the linter tests on your pull request will fail; and you'll be expected 
    to correct these issues before your submission will be transferred over for human review.

<br />
<br />

##### Packages

We use the following packages for linting and prettier.

<br />

| Package | Repo File | Description |
| --- | --- | --- |
| [@stylistic/eslint-plugin-js](https://npmjs.com/package/@stylistic/eslint-plugin-js) | [package.json](./package.json) | JavaScript stylistic rules for ESLint, migrated from eslint core. |
| [@stylistic/eslint-plugin-ts](https://npmjs.com/package/@stylistic/eslint-plugin-ts) | [package.json](./package.json) | TypeScript stylistic rules for ESLint, migrated from typescript-eslint. |
| [@stylistic/eslint-plugin-plus](https://npmjs.com/package/@stylistic/eslint-plugin-plus) | [package.json](./package.json) | Supplementary rules introduced by ESLint Stylistic. |
| [eslint-plugin-prettier](https://npmjs.com/package/eslint-plugin-prettier) | [package.json](./package.json) | Runs Prettier as an ESLint rule and reports differences as individual ESLint issues. |

<br />

You can add the following to your `package.json` file:

```json
    "devDependencies": {
        "@types/uuid": "^10.0.0",
        "all-contributors-cli": "^6.26.1",
        "uuid": "^11.1.0",
        "env-cmd": "^10.1.0",
        "eslint": "9.17.0",
        "eslint-plugin-chai-friendly": "^1.0.1",
        "eslint-plugin-import": "2.31.0",
        "eslint-plugin-n": "17.15.0",
        "eslint-plugin-promise": "7.2.1",
        "@stylistic/eslint-plugin-js": "^3.1.0"
    },
```


<br />
<br />

##### Indentation

Use `4 spaces` per indentation level.

<br />
<br />

##### Style

For files that are not controlled by [Prettier](#prettier) or [ESLint](#eslint); use `Allman Style`.  Braces should be on their own lines, and any code inside the braces should be indented 4 spaces.

<br />

```javascript
return {
    status: "failure",
    user:
    {
        id: "1aaa35aa-fb3a-62ae-ffec-a14g7fc401ac",
        label: "Test String",
    }
};

while (x == y)
{
    foo();
    bar();
}
```

<br />
<br />

##### Line Length

Keep the maximum character count to `100 characters per line`. The configs on this page have prettier automatically set up to detect more than 100 characters per line.

<br />

##### Commenting

Comment your code. It helps novice readers to better understand the process. You may use block style commenting, or single lines:

```javascript
/*
    tests to decide if the end-user is running on Darwin or another platform.
*/

test(`Return true if platform is Darwin`, () =>
{
    process.platform = 'darwin';
    expect(bIsDarwin()).toBe(true);
});

test(`Return false if platform is not Darwin`, () =>
{
    process.platform = 'linux';
    expect(bIsDarwin()).toBe(false);
});
```

<br />

##### Casing

Stick to `camelCase` as much as possible. 

```javascript
let myVar = 'one';
let secondVar = 'two';
```

<br />

If you are defining a new environment variable; it must be in ALL CAPS in the `Dockerfile`:

```dockerfile
ENV DIR_BUILD=/usr/src/app
ENV DIR_RUN=/usr/bin/app
ENV URL_REPO="https://github.com/Aetherinox/csf-firewall"
ENV WEB_IP="0.0.0.0"
ENV WEB_PORT=4124
ENV LOG_LEVEL=4
ENV TZ="Etc/UTC"
```

<br />

Then you may call your new environment variable within the Javascript code; and ensure you define a default value to correct any user misconfigurations:

```javascript
const envUrlRepo = process.env.URL_REPO || 'https://github.com/Aetherinox/csf-firewall';
```

<br />
<br />

<div align="center" markdown="1">

**[`^        back to top        ^`](#about)**

</div>

<br />
<br />

<br />
<br />

<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->

<!-- BADGE > GENERAL -->
  [general-npmjs-uri]: https://npmjs.com
  [general-nodejs-uri]: https://nodejs.org
  [general-npmtrends-uri]: http://npmtrends.com/csf-firewall

<!-- BADGE > VERSION > GITHUB -->
  [github-version-img]: https://img.shields.io/github/v/tag/aetherinox/csf-firewall?logo=GitHub&label=Version&color=ba5225
  [github-version-uri]: https://github.com/aetherinox/csf-firewall/releases

<!-- BADGE > LICENSE > MIT -->
  [license-mit-img]: https://img.shields.io/badge/MIT-FFF?logo=creativecommons&logoColor=FFFFFF&label=License&color=9d29a0
  [license-mit-uri]: https://github.com/aetherinox/csf-firewall/blob/main/LICENSE

<!-- BADGE > GITHUB > DOWNLOAD COUNT -->
  [github-downloads-img]: https://img.shields.io/github/downloads/aetherinox/csf-firewall/total?logo=github&logoColor=FFFFFF&label=Downloads&color=376892
  [github-downloads-uri]: https://github.com/aetherinox/csf-firewall/releases

<!-- BADGE > GITHUB > DOWNLOAD SIZE -->
  [github-size-img]: https://img.shields.io/github/repo-size/aetherinox/csf-firewall?logo=github&label=Size&color=59702a
  [github-size-uri]: https://github.com/aetherinox/csf-firewall/releases

<!-- BADGE > ALL CONTRIBUTORS -->
  [contribs-all-img]: https://img.shields.io/github/all-contributors/aetherinox/csf-firewall?logo=contributorcovenant&color=de1f6f&label=contributors
  [contribs-all-uri]: https://github.com/all-contributors/all-contributors

<!-- BADGE > GITHUB > BUILD > NPM -->
  [github-build-img]: https://img.shields.io/github/actions/workflow/status/aetherinox/csf-firewall/npm-release.yml?logo=github&logoColor=FFFFFF&label=Build&color=%23278b30
  [github-build-uri]: https://github.com/aetherinox/csf-firewall/actions/workflows/npm-release.yml

<!-- BADGE > GITHUB > BUILD > Pypi -->
  [github-build-pypi-img]: https://img.shields.io/github/actions/workflow/status/aetherinox/csf-firewall/release-pypi.yml?logo=github&logoColor=FFFFFF&label=Build&color=%23278b30
  [github-build-pypi-uri]: https://github.com/aetherinox/csf-firewall/actions/workflows/pypi-release.yml

<!-- BADGE > GITHUB > TESTS -->
  [github-tests-img]: https://img.shields.io/github/actions/workflow/status/aetherinox/csf-firewall/npm-tests.yml?logo=github&label=Tests&color=2c6488
  [github-tests-uri]: https://github.com/aetherinox/csf-firewall/actions/workflows/npm-tests.yml

<!-- BADGE > GITHUB > COMMIT -->
  [github-commit-img]: https://img.shields.io/github/last-commit/aetherinox/csf-firewall?logo=conventionalcommits&logoColor=FFFFFF&label=Last%20Commit&color=313131
  [github-commit-uri]: https://github.com/aetherinox/csf-firewall/commits/main/

<!-- BADGE > Github > Docker Image > SELFHOSTED BADGES -->
  [github-docker-version-img]: https://badges-ghcr.onrender.com/aetherinox/csf-firewall/latest_tag?color=%233d9e18&ignore=development-amd64%2Cdevelopment%2Cdevelopment-arm64%2Clatest&label=version&trim=
  [github-docker-version-uri]: https://github.com/aetherinox/csf-firewall/pkgs/container/csf-firewall

<!-- BADGE > Dockerhub > Docker Image -->
  [dockerhub-docker-version-img]: https://img.shields.io/docker/v/aetherinox/csf-firewall?sort=semver&arch=arm64
  [dockerhub-docker-version-uri]: https://hub.docker.com/repository/docker/aetherinox/csf-firewall/general

<!-- BADGE > Gitea > Docker Image > SELFHOSTED BADGES -->
  [gitea-docker-version-img]: https://badges-ghcr.onrender.com/aetherinox/csf-firewall/latest_tag?color=%233d9e18&ignore=latest&label=version&trim=
  [gitea-docker-version-uri]: https://git.csfirewall.net/Aetherinox/csf-firewall

<!-- BADGE > Gitea 2 > Docker Image -->
  [gitea2-docker-version-img]: https://img.shields.io/gitea/v/release/Aetherinox/csf-firewall?gitea_url=https%3A%2F%2Fgit.csfirewall.net
  [gitea2-docker-version-uri]: https://git.csfirewall.net/Aetherinox/-/packages/container/csf-firewall/latest

<!-- BADGE > BUTTON > SUBMIT ISSUES -->
  [btn-github-submit-img]: https://img.shields.io/badge/submit%20new%20issue-de1f5c?style=for-the-badge&logo=github&logoColor=FFFFFF
  [btn-github-submit-uri]: https://github.com/aetherinox/csf-firewall/issues

<!-- prettier-ignore-end -->
<!-- markdownlint-restore -->
