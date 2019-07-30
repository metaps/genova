<template>
  <p>Hello, {{ name }}</p>
</template>

<style scoped>
h1 {
  color: teal;
}
</style>

<script>
export default {
  data () {
    return {
      name: 'world'
    }
  },
  created: function() {
    console.log('hoge');
  }
}
</script>
