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
        const SnackBar(content: Text('AI provider updated')),
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u4fdd\u5b58\u5931\u8d25: $e')));
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
                        const Text('\u542f\u7528'),
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
                    '\u6700\u8fd1\u66f4\u65b0\u65f6\u95f4: ${form.updatedAt!.toLocal()}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.endpointCtrl,
                  decoration: const InputDecoration(
                    labelText: '\u670d\u52a1\u5730\u5740 URL',
                    border: OutlineInputBorder(),
                    hintText: '\u4f8b\u5982: http://localhost:11434',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.modelCtrl,
                  decoration: const InputDecoration(
                    labelText: '\u6a21\u578b\u540d\u79f0',
                    border: OutlineInputBorder(),
                    hintText: '\u4f8b\u5982: ollama/llama3',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: form.apiKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                    hintText: '\u7559\u7a7a\u8868\u793a\u4e0d\u8bbe\u7f6e Bearer Token',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: form.saving ? null : () => _save(form),
                    child: Text(form.saving ? '\u4fdd\u5b58\u4e2d...' : '\u4fdd\u5b58\u8bbe\u7f6e'),
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

