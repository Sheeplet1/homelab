# Secrets

Secrets managed through Bitnami Sealed Secrets.

To update secrets file:

```bash
kubeseal -f secrets.yaml -w sealedsecrets.yaml \
--controller-name=sealed-secrets \
--controller-namespace=kube-system
```

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
