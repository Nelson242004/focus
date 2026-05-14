import 'package:flutter/material.dart';

import '../models/ranking_profile.dart';
import '../services/friends_service.dart';
import '../services/ranking_service.dart';
import '../widgets/focus_drawer.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  Future<List<RankingProfile>>? _searchFuture;
  Future<List<RankingEntry>>? _friendsRankingFuture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _searchFuture = FriendsService.searchUsers(_searchController.text);
    });
  }

  void _loadFriendsRanking(List<RankingProfile> friends) {
    final friendIds = friends.map((friend) => friend.uid).toList();
    _friendsRankingFuture =
        RankingService.fetchFriendsLeaderboard(friendUids: friendIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const FocusDrawer(selectedRoute: 'friends'),
      appBar: AppBar(title: const Text('Amigos')),
      body: StreamBuilder<List<RankingProfile>>(
        stream: FriendsService.friendsStream(),
        builder: (context, friendsSnapshot) {
          final friends = friendsSnapshot.data ?? const <RankingProfile>[];
          _friendsRankingFuture ??= RankingService.fetchFriendsLeaderboard(
            friendUids: friends.map((friend) => friend.uid).toList(),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _Hero(friendsCount: friends.length),
              const SizedBox(height: 16),
              _SearchCard(
                controller: _searchController,
                searchFuture: _searchFuture,
                onSearch: _search,
                onSendRequest: (profile) async {
                  await FriendsService.sendRequest(profile);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solicitud enviada a ${profile.name}.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _RequestsCard(onChanged: () => setState(() {})),
              const SizedBox(height: 16),
              _FriendsList(
                friends: friends,
                onRemove: (friend) async {
                  await FriendsService.removeFriend(friend.uid);
                  if (!context.mounted) return;
                  setState(() {
                    _friendsRankingFuture = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              _FriendsRanking(
                future: _friendsRankingFuture,
                onRefresh: () => setState(() => _loadFriendsRanking(friends)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FriendsPanel extends StatelessWidget {
  final Widget child;

  const _FriendsPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String name;

  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'F' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyInline({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final int friendsCount;

  const _Hero({required this.friendsCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comunidad de estudio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$friendsCount amigos conectados a tu ranking semanal.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<RankingProfile>>? searchFuture;
  final VoidCallback onSearch;
  final Future<void> Function(RankingProfile) onSendRequest;

  const _SearchCard({
    required this.controller,
    required this.searchFuture,
    required this.onSearch,
    required this.onSendRequest,
  });

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar amigos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Nombre, carrera o uid',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onSubmitted: (_) => onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Buscar',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            if (searchFuture != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<List<RankingProfile>>(
                future: searchFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  final results = snapshot.data ?? const <RankingProfile>[];
                  if (results.isEmpty) {
                    return const Text('Sin resultados.');
                  }
                  return Column(
                    children: results
                        .map((profile) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _InitialAvatar(name: profile.name),
                              title: Text(
                                profile.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(profile.career),
                              trailing: IconButton.filledTonal(
                                tooltip: 'Enviar solicitud',
                                onPressed: () => onSendRequest(profile),
                                icon: const Icon(Icons.person_add_rounded),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  final VoidCallback onChanged;

  const _RequestsCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequest>>(
      stream: FriendsService.incomingRequestsStream(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <FriendRequest>[];
        if (requests.isEmpty) return const SizedBox.shrink();
        return _FriendsPanel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitudes pendientes',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...requests.map((request) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _InitialAvatar(name: request.fromName),
                      title: Text(
                        request.fromName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text('Quiere agregarte como amigo.'),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Aceptar',
                            onPressed: () async {
                              await FriendsService.acceptRequest(request);
                              onChanged();
                            },
                            icon: const Icon(Icons.check_rounded),
                          ),
                          IconButton(
                            tooltip: 'Rechazar',
                            onPressed: () async {
                              await FriendsService.rejectRequest(request);
                              onChanged();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FriendsList extends StatelessWidget {
  final List<RankingProfile> friends;
  final Future<void> Function(RankingProfile) onRemove;

  const _FriendsList({required this.friends, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tus amigos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (friends.isEmpty)
              const _EmptyInline(
                icon: Icons.person_add_alt_rounded,
                text: 'Todavía no agregaste amigos.',
              )
            else
              ...friends.map((friend) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _InitialAvatar(name: friend.name),
                    title: Text(
                      friend.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(friend.career),
                    trailing: IconButton(
                      tooltip: 'Eliminar amigo',
                      onPressed: () => onRemove(friend),
                      icon: const Icon(Icons.person_remove_rounded),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _FriendsRanking extends StatelessWidget {
  final Future<List<RankingEntry>>? future;
  final VoidCallback onRefresh;

  const _FriendsRanking({required this.future, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _FriendsPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ranking entre amigos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<RankingEntry>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                final entries = snapshot.data ?? const <RankingEntry>[];
                if (entries.isEmpty) {
                  return const _EmptyInline(
                    icon: Icons.leaderboard_rounded,
                    text: 'Sin datos todavía.',
                  );
                }
                return Column(
                  children: entries
                      .map((entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                '#${entry.position}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: Text(
                              entry.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(entry.career),
                            trailing: Text(
                              '${entry.points} pts',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
