import 'package:flutter/material.dart';
import 'package:performance_list_view/performance_list_view.dart';

import 'common.dart';
import 'data.dart';

/// Sticky section headers, separators and an A–Z index bar driven by
/// scrollToIndex.
class ContactsDemo extends StatefulWidget {
  const ContactsDemo({super.key});

  @override
  State<ContactsDemo> createState() => _ContactsDemoState();
}

class _ContactsDemoState extends State<ContactsDemo> {
  final _contacts = PerformanceListController<Contact>(
    initialItems: contacts(),
  );
  late final Map<String, int> _firstIndex = {
    for (var i = _contacts.length - 1; i >= 0; i--) _contacts[i].name[0]: i,
  };
  late final Map<String, int> _counts = () {
    final counts = <String, int>{};
    for (final c in _contacts.items) {
      counts[c.name[0]] = (counts[c.name[0]] ?? 0) + 1;
    }
    return counts;
  }();
  String? _active;

  @override
  void dispose() {
    _contacts.dispose();
    super.dispose();
  }

  void _jump(String letter) {
    final index = _firstIndex[letter];
    if (index == null) return;
    setState(() => _active = letter);
    // The pinned header is accounted for: the contact lands below it.
    _contacts.scrollToIndex(index, duration: const Duration(milliseconds: 420));
  }

  @override
  Widget build(BuildContext context) {
    final letters = _firstIndex.keys.toList()..sort();
    final cs = Theme.of(context).colorScheme;
    return Readable(
      child: Row(
        children: [
          Expanded(
            child: PerformanceListView<Contact>(
              listController: _contacts,
              itemKey: (c) => c.id,
              sections: PerformanceSections<Contact, String>(
                sectionOf: (c) => c.name[0],
                headerBuilder: (context, letter, _) => SizedBox(
                  height: 44,
                  child: PerformanceSectionHeader(
                    title: letter,
                    trailing: Text('${_counts[letter]}'),
                  ),
                ),
              ),
              separatorBuilder: (context, _) =>
                  const Divider(height: 1, indent: 76, endIndent: 16),
              itemBuilder: (context, c, _) => ListTile(
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 20,
                  end: 12,
                ),
                leading: Avatar(
                  initials: c.initials,
                  colors: c.colors,
                  size: 40,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(c.role),
                trailing: IconButton(
                  tooltip: 'Message ${c.name}',
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in letters)
                  Semantics(
                    button: true,
                    label: 'Jump to $l',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _jump(l),
                      child: Container(
                        width: 24,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _active == l ? cs.primaryContainer : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _active == l
                                ? cs.onPrimaryContainer
                                : cs.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
