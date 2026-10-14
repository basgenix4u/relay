{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: { renderer: 'html', useColorEmoji: false },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    const boot = document.getElementById('boot');
    if (boot) boot.remove();
  }
});
