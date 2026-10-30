import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/componentes_provider.dart';
import '../widgets/app_bar_nivel.dart';
import '../widgets/banner_sin_cuenta.dart';
import '../widgets/boton_punteado.dart';
import '../widgets/card_resultado.dart';
import '../widgets/cta_crear_cuenta.dart';
import '../widgets/fila_componente.dart';
import '../widgets/linea_pesos.dart';
import '../services/calculadora_promedio.dart';
import 'welcome_screen.dart';
import 'auth_screen.dart';
import 'ciclos_screen.dart';

/// Pantalla principal: calculadora rapida de promedio ponderado
/// (DESIGN.md pantalla 10). Sirve tanto con cuenta como sin cuenta.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _confirmarReinicio(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reiniciar la calculadora?'),
        content: const Text('Se borrarán los componentes actuales y volverás a 2 filas vacías.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      context.read<ComponentesProvider>().reiniciar();
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      user = null;
    }
    // Una cuenta sin verificar se trata como modo sin cuenta.
    final esSinCuenta = user == null || !user.emailVerified;
    final String userName = user?.email?.split('@').first ?? '';

    final reiniciar = IconButton(
      icon: const Icon(Icons.restart_alt_rounded),
      tooltip: 'Reiniciar calculadora',
      onPressed: () => _confirmarReinicio(context),
    );

    return Scaffold(
      appBar: esSinCuenta
          ? AppBarNivel(
              padre: 'Modo sin cuenta',
              titulo: 'Calculadora rápida',
              acciones: [reiniciar],
            )
          : AppBarNivel(
              padre: userName.isNotEmpty ? 'Hola, $userName' : 'Tu cuenta',
              titulo: 'Calculadora rápida',
              mostrarAtras: false,
              acciones: [
                // H10 - Acceso a gestion de ciclos
                IconButton(
                  icon: const Icon(Icons.school_rounded),
                  tooltip: 'Mis ciclos',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CiclosScreen()),
                    );
                  },
                ),
                reiniciar,
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Cerrar sesión',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
      body: Consumer<ComponentesProvider>(
        builder: (context, provider, child) {
          final componentes = provider.componentes;
          final promedio = CalculadoraPromedio.calcularPromedio(componentes);

          // Si no hay promedio, se explica por que (sin tocar la logica de H02).
          String textoSinNota = 'Sin notas aún';
          String? subtituloSinNota;
          if (promedio == null) {
            if (!provider.esSumaPesosValida) {
              textoSinNota = 'Completa los pesos';
              subtituloSinNota = 'Deben sumar 100% para calcular';
            } else {
              textoSinNota = 'Revisa los datos';
              subtituloSinNota = 'Notas de 0 a 20 y pesos mayores a 0';
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              if (esSinCuenta) ...[
                const BannerSinCuenta(),
                const SizedBox(height: 12),
              ],
              CardResultado(
                nota: promedio,
                titulo: 'Promedio final',
                subtitulo: promedio == null ? subtituloSinNota : null,
                textoSinNota: textoSinNota,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: LineaPesos(suma: provider.sumaPesos),
              ),
              const SizedBox(height: 16),
              const _EncabezadoTabla(),
              const SizedBox(height: 8),
              for (final item in componentes) ...[
                FilaComponente(
                  key: ValueKey(item.id),
                  componente: item,
                  puedeEliminar: provider.puedeEliminar,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              BotonPunteado(texto: 'Agregar componente', onPressed: provider.agregarComponente),
            ],
          );
        },
      ),
      bottomNavigationBar: esSinCuenta
          ? Consumer<ComponentesProvider>(
              builder: (context, provider, child) => CtaCrearCuenta(
                cantidadComponentes: provider.componentes.length,
                onCrearCuenta: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(modoVincular: true),
                    ),
                  );
                },
              ),
            )
          : null,
    );
  }
}

class _EncabezadoTabla extends StatelessWidget {
  const _EncabezadoTabla();

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Componente', style: estilo),
            ),
          ),
          const SizedBox(width: ColumnasComponente.separacion),
          SizedBox(
            width: ColumnasComponente.nota,
            child: Text('Nota', textAlign: TextAlign.center, style: estilo),
          ),
          const SizedBox(width: ColumnasComponente.separacion),
          SizedBox(
            width: ColumnasComponente.peso,
            child: Text('Peso %', textAlign: TextAlign.center, style: estilo),
          ),
          const SizedBox(width: ColumnasComponente.borrar + 8),
        ],
      ),
    );
  }
}
