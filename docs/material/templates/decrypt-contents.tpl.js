/* encryptcontent/decrypt-contents.tpl.js */
{%- if webcrypto %}
// https://stackoverflow.com/a/50868276
function fromHex(hexString) {
    return new Uint8Array(hexString.match(/.{1,2}/g).map(byte => parseInt(byte, 16)));
}
// https://stackoverflow.com/a/41106346
function fromBase64(base64String) {
    return Uint8Array.from(atob(base64String), c => c.charCodeAt(0));
}

async function digestSHA256toBase64(message) {
  const data = new TextEncoder().encode(message);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = new Uint8Array(hashBuffer);
  const hashString = String.fromCharCode.apply(null, hashArray);
  return btoa(hashString);
};
{%- endif %}

function base64url_decode(input) {
    try {
        const binString = atob(input.replace(/-/g, '+').replace(/_/g, '/'));
        const binArray = Uint8Array.from(binString, (m) => m.codePointAt(0));
        return new TextDecoder().decode(binArray);
    }
    catch (err) {
        return false;
    }
}

/* Decrypts the key from the key bundle. */
{% if webcrypto %}async {% endif %}function decrypt_key(pass, iv_b64, ciphertext_b64, salt_b64) {
    {%- if webcrypto %}
    const salt = fromBase64(salt_b64);
    const encPassword = new TextEncoder().encode(pass);
    const kdfkey = await window.crypto.subtle.importKey(
        "raw",
        encPassword,
        "PBKDF2",
        false,
        ["deriveKey"],
    );
    const wckey = await window.crypto.subtle.deriveKey(
        {
          name: "PBKDF2",
          salt,
          iterations: encryptcontent_obfuscate ? 1 : {{ kdf_iterations }},
          hash: "SHA-256",
        },
        kdfkey,
        { name: "AES-CBC", length: 256 },
        true,
        ["decrypt"],
    );
    const ciphertext = fromBase64(ciphertext_b64);
    const iv = fromBase64(iv_b64);
    try {
        const decrypted = await window.crypto.subtle.decrypt(
            {
                name: "AES-CBC",
                iv: iv
            },
            wckey,
            ciphertext
        );
        const keystore = JSON.parse(new TextDecoder().decode(decrypted));
        if (encryptcontent_id in keystore) {
            return keystore;
        } else {
            //id not found in keystore
            return false;
        }
    }
    catch (err) {
        // encoding failed; wrong key
        return false;
    }
    {%- else %}
    let salt = CryptoJS.enc.Base64.parse(salt_b64),
        kdfcfg = {keySize: 256 / 32,hasher: CryptoJS.algo.SHA256,iterations: encryptcontent_obfuscate ? 1 : {{ kdf_iterations }}};
    let kdfkey = CryptoJS.PBKDF2(pass, salt,kdfcfg);
    let iv = CryptoJS.enc.Base64.parse(iv_b64),
        ciphertext = CryptoJS.enc.Base64.parse(ciphertext_b64);
    let encrypted = {ciphertext: ciphertext},
        cfg = {iv: iv, mode: CryptoJS.mode.CBC, padding: CryptoJS.pad.Pkcs7};
    let key = CryptoJS.AES.decrypt(encrypted, kdfkey, cfg);

    try {
        let keystore = JSON.parse(key.toString(CryptoJS.enc.Utf8));
        if (encryptcontent_id in keystore) {
            return keystore;
        } else {
            //id not found in keystore
            return false;
        }
    } catch (err) {
        // encoding failed; wrong password
        return false;
    }
    {%- endif %}
};

/* Split key bundle and try to decrypt it */
{% if webcrypto %}async {% endif %}function decrypt_key_from_bundle(password, ciphertext_bundle, username) {
    // grab the ciphertext bundle and try to decrypt it
    let user, pass;
    let parts, keys, userhash;
    if (ciphertext_bundle) {
        if (username) {
            user = encodeURIComponent(username.toLowerCase());
            {%- if webcrypto %}
            userhash = await digestSHA256toBase64(user);
            {%- else %}
            userhash = CryptoJS.SHA256(user).toString(CryptoJS.enc.Base64);
            {%- endif %}
        }
        for (let i = 0; i < ciphertext_bundle.length; i++) {
            pass = encodeURIComponent(password);
            parts = ciphertext_bundle[i].split(';');
            if (parts.length == 3) {
                keys = {% if webcrypto %}await {% endif %}decrypt_key(pass, parts[0], parts[1], parts[2]);
                if (keys) {
                    {% if remember_password %}setCredentials(null, pass);{% endif %}
                    return keys;
                }
            } else if (parts.length == 4 && username) {
                if (parts[3] == userhash) {
                    keys = {% if webcrypto %}await {% endif %}decrypt_key(pass, parts[0], parts[1], parts[2]);
                    if (keys) {
                        {% if remember_password %}setCredentials(user, pass);{% endif %}
                        return keys;
                    }
                }
            }
        }
    }
    return false;
};

/* Decrypts the content from the ciphertext bundle. */
{% if webcrypto %}async {% endif %}function decrypt_content(key, iv_b64, ciphertext_b64) {
    {%- if webcrypto %}
    const rawKey = fromHex(key);
    const iv = fromBase64(iv_b64);
    const ciphertext = fromBase64(ciphertext_b64);
    try {
        const wckey = await window.crypto.subtle.importKey(           
            "raw",
            rawKey,                                                 
            "AES-CBC",
            true,
            ["decrypt"]
        );
        const decrypted = await window.crypto.subtle.decrypt(
            {
                name: "AES-CBC",
                iv: iv
            },
            wckey,
            ciphertext
        );
        const decoder = new TextDecoder();
        return decoder.decode(decrypted);
    }
    catch (err) {
        // encoding failed; wrong key
        return false;
    }
    {%- else %}
    let iv = CryptoJS.enc.Base64.parse(iv_b64),
        ciphertext = CryptoJS.enc.Base64.parse(ciphertext_b64);
    let encrypted = {ciphertext: ciphertext},
        cfg = {iv: iv, mode: CryptoJS.mode.CBC, padding: CryptoJS.pad.Pkcs7};
    let plaintext = CryptoJS.AES.decrypt(encrypted, CryptoJS.enc.Hex.parse(key), cfg);
    if(plaintext.sigBytes >= 0) {
        try {
            return plaintext.toString(CryptoJS.enc.Utf8)
        } catch (err) {
            // encoding failed; wrong key
            return false;
        }
    } else {
        // negative sigBytes; wrong key
        return false;
    }
    {%- endif %}
};

/* Split cyphertext bundle and try to decrypt it */
{% if webcrypto %}async {% endif %}function decrypt_content_from_bundle(key, ciphertext_bundle) {
    // grab the ciphertext bundle and try to decrypt it
    if (ciphertext_bundle) {
        let parts = ciphertext_bundle.split(';');
        if (parts.length == 2) {
            return {% if webcrypto %}await {% endif %}decrypt_content(key, parts[0], parts[1]);
        }
    }
    return false;
};

{% if- remember_keys -%}
/* Save decrypted keystore to sessionStorage */
{% if webcrypto %}async {% endif %}function setKeys(keys_from_keystore) {
    for (const id in keys_from_keystore) {
        sessionStorage.setItem(id, keys_from_keystore[id]);
    }
};

/* Delete key with specific name in sessionStorage */
{% if webcrypto %}async {% endif %}function delItemName(key) {
    sessionStorage.removeItem(key);
};

{% if webcrypto %}async {% endif %}function getItemName(key) {
    return sessionStorage.getItem(key);
};
{%- endif %}
{%- if remember_password %}
/* save username/password to sessionStorage/localStorage */
{% if webcrypto %}async {% endif %}function setCredentials(username, password) {
    {%- if session_storage %}
    sessionStorage.setItem('{{ remember_prefix }}credentials', JSON.stringify({'user': username, 'password': password}));
    {%- else %}
    localStorage.setItem('{{ remember_prefix }}credentials', JSON.stringify({'user': username, 'password': password}));
    {%- endif %}
}

/* try to get username/password from sessionStorage/localStorage */
{% if webcrypto %}async {% endif %}function getCredentials(username_input, password_input) {
    {%- if session_storage %}
    const credentials = JSON.parse(sessionStorage.getItem('{{ remember_prefix }}credentials'));
    {%- else %}
    const credentials = JSON.parse(localStorage.getItem('{{ remember_prefix }}credentials'));
    {%- endif %}
    if (credentials && !encryptcontent_obfuscate) {
        if (credentials['user'] && username_input) {
            username_input.value = decodeURIComponent(credentials['user']);
        }
        if (credentials['password']) {
            password_input.value = decodeURIComponent(credentials['password']);
        }
        return true;
    } else {
        return false;
    }
}

/*remove username/password from localStorage */
{% if webcrypto %}async {% endif %}function delCredentials() {
    {%- if session_storage %}
    sessionStorage.removeItem('{{ remember_prefix }}credentials');
    {%- else %}
    localStorage.removeItem('{{ remember_prefix }}credentials');
    {%- endif %}
}
{%- endif %}

/* Reload scripts src after decryption process */
{% if webcrypto %}async {% endif %}function reload_js(src) {
    let script_src, script_tag, new_script_tag;
    let head = document.getElementsByTagName('head')[0];

    if (src.startsWith('#')) {
        script_tag = document.getElementById(src.substr(1));
        if (script_tag) {
            script_tag.remove();
            new_script_tag = document.createElement('script');
            if (script_tag.innerHTML) {
                new_script_tag.innerHTML = script_tag.innerHTML;
            }
            if (script_tag.src) {
                new_script_tag.src = script_tag.src;
            }
            if (script_tag.type) {
                new_script_tag.type = script_tag.type;
            }
            head.appendChild(new_script_tag);
        }
    } else {
        if (base_url == '.') {
            script_src = src;
        } else {
            script_src = base_url + '/' + src;
        }

        script_tag = document.querySelector('script[src="' + script_src + '"]');
        if (script_tag) {
            script_tag.remove();
            new_script_tag = document.createElement('script');
            new_script_tag.src = script_src;
            head.appendChild(new_script_tag);
        }
    }
};

{% if experimental -%}
/* Decrypt part of the search index and refresh it for search engine */
{% if webcrypto %}async {% endif %}function decrypt_search(keys, retry=true) {
    let sessionIndex = sessionStorage.getItem('encryptcontent-index');
    let could_decrypt = false;
    if (sessionIndex) {
        sessionIndex = JSON.parse(sessionIndex);
        for (let i = 0; i < sessionIndex.docs.length; i++) {
            let doc = sessionIndex.docs[i];
            let location_sep = doc.location.indexOf(';');
            if (location_sep !== -1) {
                let location_id = doc.location.substring(0,location_sep);
                let location_bundle = doc.location.substring(location_sep+1);
                if (location_id in keys) {
                    let key = keys[location_id];
                    let location_decrypted = {% if webcrypto %}await {% endif %}decrypt_content_from_bundle(key, location_bundle);
                    if (location_decrypted) {
                        doc.location = location_decrypted;
                        doc.text = {% if webcrypto %}await {% endif %}decrypt_content_from_bundle(key, doc.text);
                        doc.title = {% if webcrypto %}await {% endif %}decrypt_content_from_bundle(key, doc.title);
                        could_decrypt = true;
                    }
                }
            }
        }
        if (could_decrypt) {
            //save decrypted index
            sessionIndex = JSON.stringify(sessionIndex);
            sessionStorage.setItem('encryptcontent-index', sessionIndex);
            // force search index reloading on Worker
            if (typeof searchWorker !== 'undefined') {
                searchWorker.postMessage({init: true, sessionIndex: sessionIndex});
            } else { //not default search plugin: reload whole page
                window.location.reload();
            }
        }
    } else if (retry) {
        setTimeout(() => { //retry after one second if 'encryptcontent-index' not available yet
            decrypt_search(keys, false);
        }, 1000);
    }
};
{%- endif %}

/* Decrypt speficique html entry from mkdocs configuration */
{% if webcrypto %}async {% endif %}function decrypt_somethings(key, encrypted_something) {
    var html_item = '';
    for (const [name, tag] of Object.entries(encrypted_something)) {
        if (tag[1] == 'id') {
            html_item = [document.getElementById(name)];
        } else if (tag[1] == 'class') {
            html_item = document.getElementsByClassName(name);
        } else {
            console.log('WARNING: Unknow tag html found, check "encrypted_something" configuration.');
        }
        if (html_item[0]) {
            for (let i = 0; i < html_item.length; i++) {
                // grab the cipher bundle if something exist
                if (html_item[i].style.display == "none") {
                    let content = {% if webcrypto %}await {% endif %}decrypt_content_from_bundle(key, html_item[i].innerHTML);
                    if (content !== false) {
                        // success; display the decrypted content
                        html_item[i].innerHTML = content;
                        html_item[i].style.display = null;
                        // any post processing on the decrypted content should be done here
                    }
                }
            }
        }
    }
    return html_item[0];
};

/* Decrypt content of a page */
{% if webcrypto %}async {% endif %}function decrypt_action(username_input, password_input, encrypted_content, decrypted_content, key_from_storage=false) {
    let key=false;
    let keys_from_keystore=false;

    let user=false;
    if (username_input) {
        user = username_input.value;
    }

    if (key_from_storage !== false) {
        key = key_from_storage;
    } else {
        keys_from_keystore = {% if webcrypto %}await {% endif %}decrypt_key_from_bundle(password_input.value, encryptcontent_keystore, user);
        if (keys_from_keystore) {
            key = keys_from_keystore[encryptcontent_id];
        }
    }

    let content = false;
    if (key) {
        content = {% if webcrypto %}await {% endif %}decrypt_content_from_bundle(key, encrypted_content.innerHTML);
    }
    if (content !== false) {
        // success; display the decrypted content
        decrypted_content.innerHTML = content;
        encrypted_content.parentNode.removeChild(encrypted_content);

        if (keys_from_keystore !== false) {
            return keys_from_keystore
        } else {
            return key
        }
    } else {
        return false
    }
};

{% if webcrypto %}async {% endif %}function decryptor_reaction(key_or_keys, password_input, decrypted_content, fallback_used=false) {
    if (key_or_keys) {
        let key;
        if (typeof key_or_keys === "object") {
            key = key_or_keys[encryptcontent_id];
            {% if remember_keys -%}
            setKeys(key_or_keys);
            {%- endif %}
            {% if experimental -%}
            decrypt_search(key_or_keys);
            {%- endif %}
        } else {
            key = key_or_keys;
        }

        // continue to decrypt others parts
        {% if encrypted_something -%}
        let encrypted_something = {{ encrypted_something }};
        decrypt_somethings(key, encrypted_something);
        {%- endif %}
        if (typeof inject_something !== 'undefined') {
            decrypted_content = {% if webcrypto %}await {% endif %}decrypt_somethings(key, inject_something);
        }
        if (typeof delete_something !== 'undefined') {
            let el = document.getElementById(delete_something)
            if (el) {
                el.remove();
            }
        }
        // any post processing on the decrypted content should be done here
    {%- if material %}
        document$.next(document);
    {%- else %}
        {% if arithmatex -%}
        if (typeof MathJax === 'object') { MathJax.typesetPromise();};
        {%- endif %}
        {% if mermaid2 -%}
        if (typeof mermaid === 'object') { mermaid.contentLoaded();};
        {%- endif %}
        {% if hljs -%}
        decrypted_content.querySelectorAll('pre code').forEach((block) => {
            hljs.highlightElement(block);
        });
        {%- endif %}
    {%- endif %}
        {% if reload_scripts | length > 0 -%}
        let reload_scripts = {{ reload_scripts }};
        for (let i = 0; i < reload_scripts.length; i++) { 
            {% if webcrypto %}await {% endif %}reload_js(reload_scripts[i]);
        }
        {%- endif %}
        if (typeof theme_run_after_decryption !== 'undefined') {
            theme_run_after_decryption();
        }
        if (window.location.hash) { //jump to anchor if hash given after decryption
            window.location.href = window.location.hash;
        }
    } else {
        // remove item on sessionStorage if decryption process fail (Invalid item)
        if (!fallback_used) {
            if (!encryptcontent_obfuscate) {
                // create HTML element for the inform message
                let mkdocs_decrypt_msg = document.getElementById('mkdocs-decrypt-msg');
                mkdocs_decrypt_msg.textContent = decryption_failure_message;
                password_input.value = '';
                password_input.focus();
            }
        }
        {% if remember_keys -%}
        delItemName(encryptcontent_id);
        {%- endif %}
    }
}

/* Trigger decryption process */
{% if webcrypto %}async {% endif %}function init_decryptor() {
    let username_input = document.getElementById('mkdocs-content-user');
    let password_input = document.getElementById('mkdocs-content-password');
    // adjust password field width to placeholder length
    //if (password_input.hasAttribute('placeholder')) {
    //    password_input.setAttribute('size', password_input.getAttribute('placeholder').length);
    //}
    let encrypted_content = document.getElementById('mkdocs-encrypted-content');
    let decrypted_content = document.getElementById('mkdocs-decrypted-content');
    let content_decrypted;
    {% if remember_keys -%}
    /* If remember_keys is set, try to use sessionStorage item to decrypt content when page is loaded */
    let key_from_storage = {% if webcrypto %}await {% endif %}getItemName(encryptcontent_id);
    if (key_from_storage) {
        content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
            username_input, password_input, encrypted_content, decrypted_content, key_from_storage
        );
        {% if remember_password -%}
        /* try to get username/password from sessionStorage */
        if (content_decrypted === false) {
            let got_credentials = {% if webcrypto %}await {% endif %}getCredentials(username_input, password_input);
            if (got_credentials) {
                content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                    username_input, password_input, encrypted_content, decrypted_content
                );
            }
        }
        {%- endif %}
        decryptor_reaction(content_decrypted, password_input, decrypted_content, true);
    }
    {% if remember_password -%}
    else {
        let got_credentials = {% if webcrypto %}await {% endif %}getCredentials(username_input, password_input);
        if (got_credentials) {
            content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                username_input, password_input, encrypted_content, decrypted_content
            );
            decryptor_reaction(content_decrypted, password_input, decrypted_content, true);
        }
    }
    {%- endif %}
    {%- endif %}
    {%- if sharelinks %}
    if (window.location.hash) {
        let location_hash = window.location.hash.substring(1)
        let anchor_hash = location_hash.search('#')
        if (anchor_hash  != -1) { //check additional anchor
            window.location.hash = location_hash.substring(anchor_hash);
            location_hash = location_hash.substring(0,anchor_hash);
        }
        if (!content_decrypted) {
            let sharestring;
            if (location_hash.startsWith('!')) {
                sharestring=decodeURIComponent(location_hash);
            } else {
                let b64u_check = base64url_decode(location_hash);
                if (b64u_check !== false) {
                    if (b64u_check.startsWith('!') && b64u_check.includes(":")) {
                        sharestring=b64u_check;
                    }
                }
            }
            if (sharestring) {
                sharestring = sharestring.substring(1);
                let pass_sep = sharestring.search(":");
                if (username_input) {
                    username_input.value = sharestring.substring(0,pass_sep);
                }
                password_input.value = sharestring.substring(pass_sep+1);
        {%- if sharelinks_incomplete %}
                if (password_input.value.endsWith(':')) {
                    if (username_input) {
                        username_input.style.display = "none";
                    }
                    let password_input_sharelink = password_input.cloneNode()
                    password_input_sharelink.id = "mkdocs-content-password-sharelink";
                    password_input_sharelink.style.display = "none";
                    password_input_sharelink.value = password_input.value;
                    password_input.value = "";
                    password_input.insertAdjacentElement('beforebegin', password_input_sharelink);
                } else {
                    content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                        username_input, password_input, encrypted_content, decrypted_content
                    );
                    decryptor_reaction(content_decrypted, password_input, decrypted_content);
                }
        {%- else %}
                content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                    username_input, password_input, encrypted_content, decrypted_content
                );
                decryptor_reaction(content_decrypted, password_input, decrypted_content);
        {%- endif %}
            }
        }
    }
    {%- endif %}
    {% if password_button -%}
    /* If password_button is set, try decrypt content when button is press */
    let decrypt_button = document.getElementById("mkdocs-decrypt-button");
    if (decrypt_button) {
        decrypt_button.onclick = {% if webcrypto %}async {% endif %}function(event) {
            event.preventDefault();
    {%- if sharelinks_incomplete %}
            let password_input_sharelink = document.getElementById('mkdocs-content-password-sharelink');
            if (password_input_sharelink) {
                password_input.value = password_input_sharelink.value + password_input.value;
            }
    {%- endif %}
            content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                username_input, password_input, encrypted_content, decrypted_content
            );
            decryptor_reaction(content_decrypted, password_input, decrypted_content);
        };
    }
    {%- endif %}
    /* Default, try decrypt content when key enter is press */
    password_input.addEventListener('keypress', {% if webcrypto %}async {% endif %}function(event) {
        if (event.key === "Enter") {
            event.preventDefault();
    {%- if sharelinks_incomplete %}
            let password_input_sharelink = document.getElementById('mkdocs-content-password-sharelink');
            if (password_input_sharelink) {
                password_input.value = password_input_sharelink.value + password_input.value;
            }
    {%- endif %}
            content_decrypted = {% if webcrypto %}await {% endif %}decrypt_action(
                username_input, password_input, encrypted_content, decrypted_content
            );
            decryptor_reaction(content_decrypted, password_input, decrypted_content);
        }
    });
    decrypted_content.style.display = '';
}

{%- if material %}
if (typeof base_url === 'undefined') {
    var base_url = JSON.parse(document.getElementById('__config').textContent).base;
}
{%- endif %}
if (document.readyState === "loading") {
  // Loading hasn't finished yet
  document.addEventListener("DOMContentLoaded", init_decryptor);
} else {
  // `DOMContentLoaded` has already fired
  init_decryptor();
}
window["init_decryptor"] = init_decryptor;
