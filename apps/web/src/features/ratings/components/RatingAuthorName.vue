<script setup lang="ts">
import { computed } from 'vue'
import { useCommunityStore } from '@/features/community/store'
import type { RatingAuthor } from '../model'

const props = defineProps<{ author: RatingAuthor }>()
const community = useCommunityStore()
const name = computed(() => community.profile?.id === props.author.id && community.profile.profile_version >= (props.author.profile_version ?? 1) ? community.profile.display_name : props.author.display_name)
</script>

<template><span>{{ name }}</span></template>
