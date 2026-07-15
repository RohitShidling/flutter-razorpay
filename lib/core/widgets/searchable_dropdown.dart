import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:meal_app/core/theme/app_theme.dart';

/// Industrial-grade reactive SearchableDropdown.
///
/// Pass [listenable], [itemsGetter], and [loadingGetter] so the
/// open bottom sheet auto-rebuilds when the provider notifies
/// (spinner shows while loading, list appears instantly when ready).
class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final String hint;
  final bool isLoading;
  final VoidCallback? onInteraction;
  final Listenable? listenable;
  final List<T> Function()? itemsGetter;
  final bool Function()? loadingGetter;
  final FormFieldSetter<T> onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    this.value,
    required this.onChanged,
    this.validator,
    this.hint = 'Select an option',
    this.isLoading = false,
    this.onInteraction,
    this.listenable,
    this.itemsGetter,
    this.loadingGetter,
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final _fieldKey = GlobalKey<FormFieldState<T>>();

  @override
  void didUpdateWidget(covariant SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the external value changes (e.g. after async fetch), update the FormFieldState
    if (widget.value != oldWidget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fieldKey.currentState?.didChange(widget.value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: _fieldKey,
      initialValue: widget.value,
      validator: widget.validator,
      // Always revalidate on value change so errors clear immediately
      // when user selects an item from the dropdown
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (FormFieldState<T> state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final hasError = state.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.enabled
                  ? () {
                      FocusScope.of(context).unfocus();
                      if (widget.onInteraction != null) widget.onInteraction!();
                      _openSheet(
                        context: context,
                        state: state,
                      );
                    }
                  : null,
              child: Opacity(
                opacity: widget.enabled ? 1 : 0.55,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasError
                        ? Colors.red
                        : (isDark
                            ? AppTheme.borderDark
                            : AppTheme.borderLight),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.value != null
                            ? widget.itemLabel(state.value as T)
                            : widget.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: state.value != null
                              ? (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight)
                              : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (widget.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CupertinoActivityIndicator(radius: 8),
                      )
                    else
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                  ],
                ),
              ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openSheet({
    required BuildContext context,
    required FormFieldState<T> state,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return _ReactiveSearchSheet<T>(
          staticItems: widget.items,
          itemLabel: widget.itemLabel,
          staticIsLoading: widget.isLoading,
          listenable: widget.listenable,
          itemsGetter: widget.itemsGetter,
          loadingGetter: widget.loadingGetter,
          onSelected: (value) {
            state.didChange(value);
            widget.onChanged(value);
            Navigator.of(sheetContext).pop();
          },
        );
      },
    ).whenComplete(() {
      // After the sheet closes, Flutter otherwise restores focus to the last
      // TextField (e.g. Roll Number), reopening the keyboard over the form.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }
}

/// Bottom sheet that listens to a [Listenable] and rebuilds reactively.
class _ReactiveSearchSheet<T> extends StatefulWidget {
  final List<T> staticItems;
  final String Function(T) itemLabel;
  final bool staticIsLoading;
  final ValueChanged<T> onSelected;
  final Listenable? listenable;
  final List<T> Function()? itemsGetter;
  final bool Function()? loadingGetter;

  const _ReactiveSearchSheet({
    required this.staticItems,
    required this.itemLabel,
    required this.staticIsLoading,
    required this.onSelected,
    this.listenable,
    this.itemsGetter,
    this.loadingGetter,
  });

  @override
  State<_ReactiveSearchSheet<T>> createState() =>
      _ReactiveSearchSheetState<T>();
}

class _ReactiveSearchSheetState<T>
    extends State<_ReactiveSearchSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<T> get _currentItems =>
      widget.itemsGetter != null
          ? widget.itemsGetter!()
          : widget.staticItems;

  bool get _currentLoading =>
      widget.loadingGetter != null
          ? widget.loadingGetter!()
          : widget.staticIsLoading;

  List<T> get _filteredItems {
    if (_query.isEmpty) return _currentItems;
    return _currentItems
        .where((item) => widget
            .itemLabel(item)
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_onDataChange);
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_onDataChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onDataChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loading = _currentLoading;
    final items = _filteredItems;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (q) => setState(() => _query = q),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: true,
                fillColor:
                    isDark ? AppTheme.surfaceDark : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Content — spinner, empty state, or list
          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 14),
                        SizedBox(height: 16),
                        Text(
                          'Loading data...',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Please wait',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            const Text(
                              'No items found',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(
                              widget.itemLabel(item),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                              ),
                            ),
                            trailing: const Icon(
                                CupertinoIcons.chevron_right,
                                size: 14,
                                color: Colors.grey),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              widget.onSelected(item);
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 4),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
