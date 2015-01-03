---
title: Namespaces
permalink: /ns/
---

Dallycot ships with a number of namespaces as core libraries. To use any of them, simply add the following to your `~/.dallycot` file.

```
uses "http://www.dallycot.net/ns/something/1.0/#";
```

This will allow you to use definitions described in the document at `http://www.dallycot.net/ns/something/1.0/`. Of course, change the URL to match that of the library's. Even though the browser doesn't need the hash (#) at the end, included it when referencing the library.

{% for namespace in site.namespaces %}{% if namespace.url != page.url %}
| [{{namespace.title}}]({{namespace.url}}) | `http://www.dallycot.net{{namespace.url}}#` |{% endif %}{% endfor %}
