import 'package:flutter/material.dart';
import '../core/controller.dart';
import 'theme.dart';
import 'dialogs.dart';

class AuthPage extends StatefulWidget {
  final AppController c;
  const AuthPage(this.c, {super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      workspace = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    workspace.dispose();
    super.dispose();
  }

  Future<void> submit({bool demo = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.c.login(
          demo
              ? '/auth/demo'
              : register
                  ? '/auth/register'
                  : '/auth/login',
          demo
              ? {}
              : {
                  'email': email.text.trim(),
                  'password': password.text,
                  if (register) 'name': name.text,
                  if (register) 'workspace': workspace.text
                });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: LayoutBuilder(builder: (ctx, size) {
        final wide = size.maxWidth > 900;
        final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 375),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!wide) ...[const Brand(), const SizedBox(height: 42)],
                  Text(
                      register
                          ? 'Start a better conversation.'
                          : 'Good to have you here.',
                      style: const TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.1,
                          height: 1.2)),
                  const SizedBox(height: 10),
                  Text(
                      register
                          ? 'A thoughtful workspace for your growing community.'
                          : 'Sign in to your workspace. Your community is waiting.',
                      style: const TextStyle(
                          fontSize: 12, color: muted, height: 1.6)),
                  const SizedBox(height: 30),
                  errorBox(error),
                  if (register) ...[
                    FieldLabel('Your name',
                        child: input(name, hint: 'Alex Morgan')),
                    gap(),
                    FieldLabel('Workspace name',
                        child: input(workspace, hint: 'e.g. Acme Studio')),
                    gap()
                  ],
                  FieldLabel('Email address',
                      child: TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                              hintText: 'you@company.com'))),
                  gap(),
                  FieldLabel('Password',
                      help: register ? 'Use at least 8 characters.' : null,
                      child: TextField(
                          controller: password,
                          obscureText: hidden,
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password
                          ],
                          style: const TextStyle(fontSize: 12),
                          onSubmitted: (_) {
                            if (!busy) submit();
                          },
                          decoration: InputDecoration(
                              hintText: register
                                  ? 'Create a password'
                                  : 'Enter your password',
                              suffixIcon: IconButton(
                                  tooltip: hidden
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => hidden = !hidden),
                                  icon: Icon(
                                      hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 17,
                                      color: muted))))),
                  const SizedBox(height: 23),
                  SizedBox(
                      width: double.infinity,
                      child: ActionButton(
                          register ? 'Create your workspace' : 'Sign in',
                          icon: Icons.arrow_forward_rounded,
                          primary: true,
                          busy: busy,
                          onPressed: () => submit())),
                  const SizedBox(height: 19),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                        padding: EdgeInsets.symmetric(horizontal: 13),
                        child: Text('or take a look around',
                            style: TextStyle(fontSize: 10, color: muted))),
                    Expanded(child: Divider())
                  ]),
                  const SizedBox(height: 19),
                  SizedBox(
                      width: double.infinity,
                      child: ActionButton('Explore the demo',
                          icon: Icons.auto_awesome_outlined,
                          onPressed: busy ? null : () => submit(demo: true))),
                  const SizedBox(height: 22),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                        register
                            ? 'Already part of the community?'
                            : 'New here?',
                        style: const TextStyle(fontSize: 11, color: muted)),
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  register = !register;
                                  error = null;
                                }),
                        child: Text(register ? 'Sign in' : 'Create an account',
                            style: const TextStyle(fontSize: 11)))
                  ]),
                  const SizedBox(height: 17),
                  const Text(
                      'By continuing, you agree to keep your marketing thoughtful, permission-based, and respectful of people’s privacy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9, color: Color(0xFFA0A69C), height: 1.7)),
                ]));
        final right = Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(30), child: Center(child: form)));
        if (!wide) {
          return Center(
              child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  child: form));
        }
        return Row(children: [
          Expanded(
              child: Container(
                  color: const Color(0xFFEDF3E4),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(46, 38, 46, 36),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Brand(),
                            const Spacer(),
                            const Text('Big reach.\nPersonal touch.',
                                style: TextStyle(
                                    fontSize: 49,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -2.5,
                                    height: 1.12)),
                            const SizedBox(height: 22),
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 340),
                                child: const Text(
                                    'Turn a list of contacts into a community. The right people, the right words, one thoughtful message at a time.',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF7A866E),
                                        height: 1.8))),
                            const SizedBox(height: 36),
                            ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 360),
                                child: Transform.rotate(
                                    angle: -.025,
                                    child: const Surface(
                                        padding: EdgeInsets.all(23),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                InitialAvatar('Amara Okafor',
                                                    size: 34),
                                                SizedBox(width: 10),
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text('A real connection.',
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                      Text(
                                                          'Not just another number.',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color: muted))
                                                    ]),
                                                Spacer(),
                                                Icon(
                                                    Icons
                                                        .favorite_outline_rounded,
                                                    size: 22,
                                                    color: forest)
                                              ]),
                                              SizedBox(height: 18),
                                              Text(
                                                  '“Your little thank-you made my day. Can’t wait to shop with you again!”',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      height: 1.8,
                                                      color: forest)),
                                              SizedBox(height: 16),
                                              Row(children: [
                                                Icon(Icons.done_all_rounded,
                                                    size: 15, color: forest),
                                                SizedBox(width: 6),
                                                Text('Delivered with care.',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: muted))
                                              ])
                                            ])))),
                            const Spacer(),
                            const Row(children: [
                              Icon(Icons.verified_user_outlined,
                                  size: 15, color: forest),
                              SizedBox(width: 7),
                              Text('Consent-first. People-always.',
                                  style: TextStyle(fontSize: 10, color: forest))
                            ])
                          ])))),
          right
        ]);
      })));
}
