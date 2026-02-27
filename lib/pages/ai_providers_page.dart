part of 'package:windblog_admin_flutter/main.dart';

class AiProvidersPage extends StatefulWidget {
  const AiProvidersPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<AiProvidersPage> createState() => _AiProvidersPageState();
}

class _AiProvidersPageState extends State<AiProvidersPage> {
  final List<_ProviderForm> forms = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final form in forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final configs = await widget.api.listAiProviders();
      setState(() {
        for (final form in forms) {
          form.dispose();
        }
        forms
          ..clear()
          ..addAll(configs.map(_ProviderForm.fromConfig));
      });
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _save(_ProviderForm form) async {
    if (form.saving) return;
    if (!mounted) return;
    setState(() => form.saving = true);
    try {
      final updated = await widget.api.updateAiProvider(
        form.provider,
        AiProviderConfigUpdateRequest(
          enabled: form.enabled,
          endpoint: form.endpointCtrl.text.trim(),
          model: form.modelCtrl.text.trim(),
          apiKey: form.apiKeyCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        form.enabled = updated.enabled;
        form.endpointCtrl.text = updated.endpoint ?? '';
        form.modelCtrl.text = updated.model ?? '';
        form.apiKeyCtrl.text = updated.apiKey ?? '';
        form.updatedAt = updated.updatedAt;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'ai_provider_updated'))),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'save_failed')}$e')));
    } finally {
      if (mounted) {
        setState(() => form.saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: forms.length,
      itemBuilder: (context, index) {
        final form = forms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      form.provider,
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(t(context, 'enabled')),
                        Switch(
                          value: form.enabled,
                          onChanged: (value) =>
                              setState(() => form.enabled = value),
                        ),
                      ],
                    ),
                  ],
                ),
                if (form.updatedAt != null)
                  Text(
                    '${t(context, 'last_updated')}${form.updatedAt!.toLocal()}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.endpointCtrl,
                  decoration: InputDecoration(
                    labelText: t(context, 'endpoint_url'),
                    border: const OutlineInputBorder(),
                    hintText: t(context, 'endpoint_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.modelCtrl,
                  decoration: InputDecoration(
                    labelText: t(context, 'model_name'),
                    border: const OutlineInputBorder(),
                    hintText: t(context, 'model_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.apiKeyCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: t(context, 'api_key'),
                    border: const OutlineInputBorder(),
                    hintText: t(context, 'api_key_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: form.saving ? null : () => _save(form),
                    child: Text(form.saving ? t(context, 'saving') : t(context, 'save_settings')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProviderForm {
  _ProviderForm({
    required this.provider,
    required this.endpointCtrl,
    required this.modelCtrl,
    required this.apiKeyCtrl,
    this.enabled = false,
    this.updatedAt,
  });

  factory _ProviderForm.fromConfig(AiProviderConfig config) {
    return _ProviderForm(
      provider: config.provider,
      endpointCtrl: TextEditingController(text: config.endpoint ?? ''),
      modelCtrl: TextEditingController(text: config.model ?? ''),
      apiKeyCtrl: TextEditingController(text: config.apiKey ?? ''),
      enabled: config.enabled,
      updatedAt: config.updatedAt,
    );
  }

  final String provider;
  final TextEditingController endpointCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController apiKeyCtrl;
  bool enabled;
  bool saving = false;
  DateTime? updatedAt;

  void dispose() {
    endpointCtrl.dispose();
    modelCtrl.dispose();
    apiKeyCtrl.dispose();
  }
}
