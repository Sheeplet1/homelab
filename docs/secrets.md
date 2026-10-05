# Secrets

Secrets managed through Bitnami Sealed Secrets.

To update secrets file:

```bash
kubeseal -f secrets.yaml -w sealedsecrets.yaml \
--controller-name=sealed-secrets \
--controller-namespace=kube-system
```

When adding keys to an existing SealedSecret, merge them so its other encrypted values are
preserved:

```bash
kubeseal -f secrets.yaml \
--merge-into sealedsecrets.yaml \
--format yaml \
--controller-name=sealed-secrets \
--controller-namespace=kube-system
```

Files named `secrets.yaml` are ignored by Git. Delete the plaintext file after sealing it.

To apply new secrets file:

```bash
k apply -f sealedsecrets.yaml
```

To validate new secrets file:

```bash
cat sealedsecrets.yaml | kubeseal --validate \
--controller-name=sealed-secrets \
--controller-namespace=kube-system
```
