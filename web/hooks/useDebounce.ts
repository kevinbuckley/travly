"use client";

import { useRef, useCallback } from "react";

/**
 * Returns a debounced version of the callback that delays execution
 * until `delay` ms have passed since the last invocation.
 * Calls are coalesced by merging partial updates.
 */
export function useDebouncedSave<T>(
  saveFn: (changes: Partial<T>) => Promise<void>,
  delay = 800
) {
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pending = useRef<Partial<T>>({});

  const flush = useCallback(() => {
    if (timer.current) {
      clearTimeout(timer.current);
      timer.current = null;
    }
    if (Object.keys(pending.current).length > 0) {
      const changes = { ...pending.current };
      pending.current = {};
      saveFn(changes);
    }
  }, [saveFn]);

  const save = useCallback(
    (changes: Partial<T>) => {
      pending.current = { ...pending.current, ...changes };
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(flush, delay);
    },
    [flush, delay]
  );

  return { save, flush };
}
