# Local Three-Node Login

For local A/B/C node testing, enter the Portal domain below in the App login
domain field:

```text
A: host.docker.internal:18448
B: host.docker.internal:28448
C: host.docker.internal:38448
```

Do not enter the Matrix client API ports in the App login domain field:

```text
127.0.0.1:18008
127.0.0.1:28008
127.0.0.1:38008
```

The debug build uses `DIREXIO_LOCAL_ENDPOINTS` to resolve the recommended
Portal domains above to the local Matrix API ports internally. Testers should
only need the Portal domain and password.
