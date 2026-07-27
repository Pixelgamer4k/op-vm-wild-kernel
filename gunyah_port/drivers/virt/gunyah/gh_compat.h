/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef __GH_COMPAT_5_15_H
#define __GH_COMPAT_5_15_H

/*
 * Helpers present in newer kernels but missing (or incomplete) on Android 5.15 GKI.
 */

#ifndef overflows_type
#define overflows_type(n, type) ({			\
	typeof(n) __n = (n);				\
	(__n) != (type)(__n);				\
})
#endif

#endif /* __GH_COMPAT_5_15_H */
